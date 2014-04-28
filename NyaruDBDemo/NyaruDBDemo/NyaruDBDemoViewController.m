//
//  NyaruDBDemoViewController.m
//  NyaruDBDemo
//
//  Created by Kelp on 2013/02/22.
//
//

#import "NyaruDBDemoViewController.h"

@interface NyaruDBDemoViewController ()

@end

@implementation NyaruDBDemoViewController


#pragma mark - View events
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // instance NyaruCollection
    NyaruDB *db;
    @try {
        db = [NyaruDB instance];
    }
    @catch (__unused NSException *exception) {
        [NyaruDB reset];
        db = [NyaruDB instance];
    }
    _co = [db collection:@"demo"];
    [_co createIndex:@"updateTime"];
    
    // set up date formatter
    _dateFormatter = [NSDateFormatter new];
    [_dateFormatter setDateStyle:NSDateFormatterNoStyle];
    [_dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    
    // set up button on navigation
    UIBarButtonItem *leftButton = [[UIBarButtonItem alloc] initWithTitle:@"Speed test" style:UIBarButtonItemStylePlain target:self action:@selector(clickTestSpeed:)];
    self.navigationItem.leftBarButtonItem = leftButton;
    UIBarButtonItem *rightButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(clickInsertDocument:)];
    self.navigationItem.rightBarButtonItem = rightButton;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}


#pragma mark - UI events
/**
 Insert data into NyaruDB.
 */
- (void)clickInsertDocument:(id)sender
{
    NSInteger random = arc4random() % 100;
    [_co put:@{@"title": [NSString stringWithFormat:@"Nyaru %li", (long)random],
     @"updateTime": [NSDate date]}];
    
    [_tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationFade];
}
/**
 Speed test. Results are in the debug console.
 */
- (void)clickTestSpeed:(id)sender
{
    NyaruDB *db = [NyaruDB instance];
    
    [db removeCollection:@"speed"];
    NyaruCollection *collection = [db collection:@"speed"];
    [collection createIndex:@"group"];
    
    NSMutableDictionary *doc = [[NSMutableDictionary alloc] initWithDictionary:@{
                                                                                 @"name": @"Test",
                                                                                 @"url": @"https://github.com/kelp404/NyaruDB",
                                                                                 @"phone": @"0123456",
                                                                                 @"address": @"1600 Amphitheatre Parkway Mountain View, CA 94043, USA",
                                                                                 @"email": @"test@phate.org",
                                                                                 @"level": @0,
                                                                                 @"updateTime": @""
                                                                                 }];
    NSDate *timer = [NSDate date];
    for (NSInteger loop = 0; loop < 1000; loop++) {
        [doc setObject:[NSNumber numberWithInt:arc4random() % 512] forKey:@"group"];
        [collection put:doc];
    }
    NSLog(@"------------------------------------------------");
    NSLog(@"insert 1k data cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
    [collection waitForWriting];
    
    timer = [NSDate date];
    if (collection.all.fetch) { }
    NSLog(@"------------------------------------------------");
    NSLog(@"fetch 1k data cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
    
    timer = [NSDate date];
    for (NSInteger index = 0; index < 10; index++) {
        if ([collection where:@"group" equal:[NSNumber numberWithInt:arc4random() % 10]].count) {}
    }
    NSLog(@"------------------------------------------------");
    NSLog(@"search documents in 1k data for 10 times cost : %f ms", [timer timeIntervalSinceNow] * -1000.0);
    NSLog(@"------------------------------------------------");
}


#pragma mark - TableView delegate
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NyaruQuery *query = [_co.all orderByDESC:@"updateTime"];
    NSMutableDictionary *document = [[query fetch:1 skip:indexPath.row] lastObject];
    
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.textLabel.text = document[@"title"];
    cell.detailTextLabel.text = [_dateFormatter stringFromDate:document[@"updateTime"]];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NyaruQuery *query = [_co.all orderByDESC:@"updateTime"];
        NSMutableDictionary *document = [[query fetch:1 skip:indexPath.row] lastObject];
        [_co removeByKey:document[@"key"]];
        [tableView beginUpdates];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        [tableView endUpdates];
    }
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _co.count;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

//
//  NyaruDBDemoViewController.h
//  NyaruDBDemo
//
//  Created by Kelp on 2013/02/22.
//
//

#import <UIKit/UIKit.h>
#import <NyaruDB/NyaruDB.h>

@interface NyaruDBDemoViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
    IBOutlet UITableView *_tableView;
    
    // NyaruCollection
    NyaruCollection *_co;
    
    // date format
    NSDateFormatter *_dateFormatter;
}

@end

//
//  MainSideBarController.h
//  Caravelle
//
//  Created by Nuno on 01/02/16.
//  Copyright © 2016 Nuno Brum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface MainSideBarController : NSViewController <NSOutlineViewDelegate, NSOutlineViewDataSource, NSMenuDelegate> {
@private
    NSArray *_topLevelItems;
    NSMutableDictionary *_childrenDictionary;
    IBOutlet NSOutlineView *_sidebarOutlineView;
    
}

//@property (assign) IBOutlet NSWindow *window;


//- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
- (IBAction)sidebarMenuDidChange:(id)sender;

@end
//
//  AppDelegate.h
//  FileCatalyst1
//
//  Created by Viktoryia Labunets on 12/28/12.
//  Copyright (c) 2012 Nuno Brum. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FileCollection.h"
#import "BrowserController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSFileManagerDelegate, NSTextFieldDelegate> {
    //FileCollection *fileCollection;
    BrowserController *myLeftView;
    BrowserController *myRightView;
    //__weak LeftDataSource *_RightDataSrc;
}
@property (unsafe_unretained) IBOutlet NSWindow *myWindow;
@property (weak) IBOutlet NSTextFieldCell *StatusBar;
@property (weak) IBOutlet NSSplitView *ContentSplitView;
@property (weak) IBOutlet NSProgressIndicator *statusProgressIndicator;
@property (weak) IBOutlet NSTextField *statusProgressLabel;

@property (weak) IBOutlet NSButton *statusCancelButton;

- (IBAction)FindDuplicates:(id)sender;

/* Toolbar Actions */
- (IBAction)toolbarInformation:(id)sender;
- (IBAction)toolbarRename:(id)sender;
- (IBAction)toolbarSearch:(id)sender;
- (IBAction)toolbarGrouping:(id)sender;

- (IBAction)toolbarDelete:(id)sender;
- (IBAction)toolbarCopy:(id)sender;
- (IBAction)toolbarMove:(id)sender;
- (IBAction)toolbarOpen:(id)sender;

- (IBAction)toolbarRefresh:(id)sender;
- (IBAction)toolbarHome:(id)sender;

- (IBAction)toolbarNewFolder:(id)sender;

- (IBAction)operationCancel:(id)sender;

- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;

/* Rename Dialog */
@property (weak) IBOutlet NSTextField *ebRenameHead;
@property (weak) IBOutlet NSTextField *ebRenameExtension;
@property (weak) IBOutlet NSPanel *panelRename;

- (IBAction) renameAction:(id) sender;
- (IBAction) renameCancel:(id) sender;


@end

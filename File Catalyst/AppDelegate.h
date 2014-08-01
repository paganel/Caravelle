//
//  AppDelegate.h
//  FileCatalyst1
//
//  Created by Viktoryia Labunets on 12/28/12.
//  Copyright (c) 2012 Nuno Brum. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FileCollection.h"
#import "LeftDataSource.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    FileCollection *fileCollection;
    __weak NSOutlineView *_LeftOutlineView;
    LeftDataSource *_LeftDataSrc;
    //__weak LeftDataSource *_RightDataSrc;
}
@property (unsafe_unretained) IBOutlet NSWindow *window;

//@property (assign) IBOutlet NSWindow *window;

@property (weak) IBOutlet NSOutlineView *LeftOutlineView;
@property (weak) IBOutlet NSTableView *LeftTableView;
@property (weak) IBOutlet NSSearchField *LeftFilter;

@property (weak) IBOutlet NSTextFieldCell *StatusBar;

//@property (weak) IBOutlet NSOutlineView *RightOutlineView;
//@property (weak) IBOutlet NSTableView *RightTableView;


@property IBOutlet LeftDataSource *LeftDataSrc;
@property (weak) IBOutlet LeftDataSource *RightDataSrc;

@property (weak) IBOutlet NSToolbarItem *toolbarDeleteButton;

@property (weak) IBOutlet NSPathCell *LeftPathBar;

//- (IBAction)LeftRootBrowse:(id)sender; // Add Directories to Left View
- (IBAction)RemoveDirectory:(id)sender; // Remove Directories from Left View

- (IBAction)FindDuplicates:(id)sender;
- (IBAction)TableSelector:(id)sender;

- (IBAction)LeftOutlineCellSelector:(id)sender;

// Binding is done manually
- (IBAction)TableDoubleClickEvent:(id)sender;

- (void) DirectoryScan:(NSString*)rootPath;

- (IBAction)toolbarDelete:(id)sender;
- (IBAction)toolbarCatalystSwitch:(id)sender;
- (IBAction)PathSelect:(id)sender;
- (IBAction)LeftFilterChange:(id)sender;



@end

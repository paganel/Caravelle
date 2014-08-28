//
//  myTableView.h
//  File Catalyst
//
//  Created by Viktoryia Labunets on 21/08/14.
//  Copyright (c) 2014 Nuno Brum. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "TreeBranch.h"

@interface MYTableView : NSTableView <NSDraggingDestination> {
    TreeBranch *_treeNodeSelected;
}

-(TreeBranch *)treeNodeSelected;

-(void) setTreeNodeSelected:(TreeBranch*) node;

@end

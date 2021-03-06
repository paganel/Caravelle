//
//  MyDirectoryEnumerator.h
//  File Catalyst
//
//  Created by Nuno Brum on 15/04/14.
//  Copyright (c) 2014 Nuno Brum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Definitions.h"
#import "TreeItem.h"

extern NSArray *urlKeyFieldsToStore();

@interface MyDirectoryEnumerator : NSDirectoryEnumerator

-(MyDirectoryEnumerator *) init:(NSURL*)directoryToScan WithMode:(EnumBrowserViewMode) viewMode;

@end

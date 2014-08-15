//
//  PathControlManager.h
//  File Catalyst
//
//  Created by Viktoryia Labunets on 09/08/14.
//  Copyright (c) 2014 Nuno Brum. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PathControlManager : NSPathControl {
    NSString *_rootPath;
    NSInteger _rootLevel;
}

-(void) setRootPath:(NSURL*) rootPath Catalyst:(BOOL) catalystMode;
-(void) setURL:(NSURL*)aURL;
-(NSURL*) URL;

@end
//
//  PathControlManager.h
//  File Catalyst
//
//  Created by Viktoryia Labunets on 09/08/14.
//  Copyright (c) 2014 Nuno Brum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Definitions.h"

@interface PathControlManager : NSObject {
    NSString *_rootPath;
    NSInteger _rootLevel;
}

-(PathControlManager*) initWithBar:(NSPathControl*)pathBar andButton:(NSPopUpButton*)popButton;

-(void) setRootPath:(NSURL*) rootPath;
-(void) setURL:(NSURL*)aURL;
-(NSURL*) URL;

@end


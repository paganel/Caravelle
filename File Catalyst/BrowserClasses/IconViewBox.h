//
//  IconViewBox.h
//  Caravelle
//
//  Created by Nuno Brum on 09/04/15.
//  Copyright (c) 2015 Nuno Brum. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IconViewBox : NSBox {

}
@property (strong) IBOutlet id delegate;
@property (strong) IBOutlet NSImageView *image;
@property (strong) IBOutlet NSTextField *name;

-(id) representedObject;

@end

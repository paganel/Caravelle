//
//  myValueTransformers.h
//  File Catalyst
//
//  Created by Viktoryia Labunets on 26/10/14.
//  Copyright (c) 2014 Nuno Brum. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DateToStringTransformer: NSValueTransformer {
    NSDateFormatter *transformer;
}
-(instancetype) initWithFormat:(NSString*)format;

@end


@interface SizeToStringTransformer : NSValueTransformer 

@end

extern DateToStringTransformer *DateToYearTransformer();
extern DateToStringTransformer *DateToMonthTransformer();
extern DateToStringTransformer *DateToDayTransformer();
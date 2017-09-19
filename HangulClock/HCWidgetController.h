//
//  HCWidgetController.h
//  Hangul Clock for Mac
//
//  Created by MR.LEE(상훈) on 2017. 2. 8..
//  Copyright © 2017년 tracesOf. All rights reserved.
//

#ifndef HCWidgetController_h
#define HCWidgetController_h

#import <Cocoa/Cocoa.h>
@class HCScreensController;
@class HCWidgetsStore;

@interface HCWidgetsController : NSController

- (id)initWithMenu:(NSMenu*)menu
           widgets:(HCWidgetsStore*)theWidgets
           screens:(HCScreensController*)screens;
- (void)render;
- (NSArray*)widgetsForScripting;
- (void)refreshHangulClock:(float)seconds;

@end

#endif /* HCWidgetController_h */

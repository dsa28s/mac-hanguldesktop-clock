/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Copyright (c) 2013 Felix Hageloh.
 */

#import <Cocoa/Cocoa.h>
#import "HCScreenChangeListener.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, NSUserNotificationCenterDelegate, HCScreenChangeListener>

@property (weak) IBOutlet NSMenu *statusBarMenu;
@property (readonly) NSArray* widgets;

- (void)widgetDirDidChange;
- (void)compatibilityModeDidChange;
- (void)screensChanged:(NSDictionary*)screens;
- (IBAction)showPreferences:(id)sender;
- (IBAction)openWidgetDir:(id)sender;
- (IBAction)showDebugConsole:(id)sender;
- (IBAction)refreshWidgets:(id)sender;

@end

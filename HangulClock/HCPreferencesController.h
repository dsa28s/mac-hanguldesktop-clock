/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import <Cocoa/Cocoa.h>

@interface HCPreferencesController : NSWindowController

@property (weak) IBOutlet NSToolbar* toolbar;
@property (weak) IBOutlet NSPopUpButton *filePicker;
@property (weak) IBOutlet NSMatrix *interactionShortcutRadio;
@property BOOL startAtLogin;
@property BOOL compatibilityMode;
@property NSURL* widgetDir;

- (IBAction)showFilePicker:(id)sender;
- (IBAction)shortcutKeyChanged:(id)sender;

- (CGEventFlags)interactionShortcut;

@end

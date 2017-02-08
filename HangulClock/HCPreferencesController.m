/**
 * Project. Hangul Clock Desktop Widget for Mac
 * User: MR.LEE(leeshoon1344@gmail.com)
 * Based on uebersicht
 * License GPLv3
 * Original Copyright (c) 2013 Felix Hageloh.
 */

#import "HCPreferencesController.h"

@implementation HCPreferencesController {
    LSSharedFileListRef loginItems;
    NSDictionary* shortcutMapping;
    NSDictionary* shortcutKeyMapping;
    CGEventFlags currentShortcut;
}

@synthesize filePicker;
@synthesize toolbar;
@synthesize interactionShortcutRadio;

- (id)initWithWindowNibName:(NSString *)windowNibName
{
    self = [super initWithWindowNibName:windowNibName];
    if (self) {
        // set default widget dir and create it if it doesn't exist
        [self setDefaultWidgetDir];
        [self setDefaultInteractionShortcutKey];
        
        // watch for login item changes
        loginItems = LSSharedFileListCreate(NULL,
                                            kLSSharedFileListSessionLoginItems,
                                            NULL);
        
        LSSharedFileListAddObserver(loginItems,
                                    CFRunLoopGetMain(),
                                    kCFRunLoopCommonModes,
                                    loginItemsChanged,
                                    (__bridge void*)self);
        shortcutMapping = @{
            @"cmd"  : @(kCGEventFlagMaskCommand),
            @"ctrl" : @(kCGEventFlagMaskControl),
            @"alt"  : @(kCGEventFlagMaskAlternate),
            @"shift": @(kCGEventFlagMaskShift),
            @"none" : @(0x00000000)
        };
        
        // i'd like to skip this
        shortcutKeyMapping = @{
           @1: @"cmd",
           @2: @"ctrl",
           @3: @"alt",
           @4: @"shift",
           @5: @"none"
        };
        
        [self setInteractionShortcut:[self getInteractionShortcutKey]];
        
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    [[self.window standardWindowButton:NSWindowMiniaturizeButton] setEnabled:NO];
    [[self.window standardWindowButton:NSWindowZoomButton] setEnabled:NO];
    
    [toolbar setSelectedItemIdentifier:@"general"];
    [self widgetDirChanged:self.widgetDir];
    
    NSString* shortcutKey = [self getInteractionShortcutKey];
    NSNumber* tag = [shortcutKeyMapping allKeysForObject:shortcutKey][0];
    [interactionShortcutRadio selectCellWithTag:[tag integerValue]];
    
}

#
#pragma mark Widget Directory
#

- (IBAction)showFilePicker:(id)sender
{
    NSOpenPanel* openPanel = [NSOpenPanel openPanel];
    
    [openPanel setCanChooseFiles:NO];
    [openPanel setCanChooseDirectories:YES];
    
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            [self setWidgetDir:[openPanel URLs][0]];
        }
        
        [filePicker selectItemAtIndex:0];
    }];
}

- (NSURL*)widgetDir
{
    NSData* widgetDir = [[NSUserDefaults standardUserDefaults]
                         objectForKey:@"widgetDirectory"];
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:widgetDir];
}

- (void)setWidgetDir:(NSURL*)newDir
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:newDir]
                 forKey:@"widgetDirectory"];
    
    [self widgetDirChanged:newDir];
}

- (void)widgetDirChanged:(NSURL*)url
{
    NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:[url path]];
    [iconImage setSize:NSMakeSize(16,16)];
    
    // TODO: see if we could use bindings for this
    [[filePicker itemAtIndex:0] setTitle: [url path]];
    [[filePicker itemAtIndex:0] setImage:iconImage];
}


- (void)setDefaultWidgetDir
{
    NSArray* urls = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory
                                                           inDomains:NSUserDomainMask];
    
    NSURL* defaultDir  = [urls[0] URLByAppendingPathComponent:@"HangulClock/clocks"
                                                  isDirectory:YES];
    
    [self createIfNotExists:defaultDir];
    
    NSData* encodedDir = [NSKeyedArchiver archivedDataWithRootObject:defaultDir];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject:encodedDir
                                                            forKey:@"widgetDirectory"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    
}

- (void)createIfNotExists:(NSURL*)defaultWidgetDir
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    NSError* error;
    
    if ([fileManager fileExistsAtPath:[defaultWidgetDir path] isDirectory:&isDir] && isDir) {
        [fileManager removeItemAtPath:defaultWidgetDir error:&error];
    }
    
    [fileManager createDirectoryAtURL:defaultWidgetDir
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];

    if (error) {
        NSLog(@"%@", error);
        return;
    }
    
    NSURL* blackClock = [[NSBundle mainBundle] URLForResource:@"블랙 한글시계" withExtension:@"coffee"];
    
    [fileManager copyItemAtURL:blackClock
                         toURL:[defaultWidgetDir URLByAppendingPathComponent:@"블랙 한글시계.coffee"]
                         error:&error];
    
    NSURL* whiteClock = [[NSBundle mainBundle] URLForResource:@"화이트 한글시계" withExtension:@"coffee"];
    
    [fileManager copyItemAtURL:whiteClock
                         toURL:[defaultWidgetDir URLByAppendingPathComponent:@"화이트 한글시계.coffee"]
                         error:&error];
    
    if (error) {
        NSLog(@"%@", error);
    }
    
}

#
#pragma mark Interaction Shortcut
#

- (IBAction)shortcutKeyChanged:(id)sender
{
    NSInteger tag = [[sender selectedCell] tag];
    [self setInteractionShortcut:shortcutKeyMapping[@(tag)]];

}

- (CGEventFlags)interactionShortcut
{
    return currentShortcut;
}

- (NSString *)getInteractionShortcutKey
{
    NSData* data = [[NSUserDefaults standardUserDefaults]
                        objectForKey:@"interactionShortcut"];
    
    return [NSKeyedUnarchiver unarchiveObjectWithData:data];
}

- (void)setDefaultInteractionShortcutKey
{
    
    NSData* encodedKey = [NSKeyedArchiver archivedDataWithRootObject:@"none"];
    NSDictionary *appDefaults = [NSDictionary dictionaryWithObject:encodedKey
                                                            forKey:@"interactionShortcut"];
    [[NSUserDefaults standardUserDefaults] registerDefaults:appDefaults];
    
}

- (void)setInteractionShortcut:(NSString*)shortcutKey
{
    NSNumber* shortcut = [shortcutMapping objectForKey:shortcutKey];
    if (!shortcut) return;
    
    currentShortcut = [shortcut unsignedIntValue];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:shortcutKey]
                 forKey:@"interactionShortcut"];
}


- (BOOL)compatibilityMode
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults valueForKey:@"compatibilityMode"] boolValue];
}

- (void)setCompatibilityMode:(BOOL)enabled
{
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:@(enabled) forKey:@"compatibilityMode"];
    //[(AppDelegate *)[NSApp delegate] compatibilityModeDidChange];
}

#
#pragma mark Startup
#

- (BOOL)startAtLogin
{
    return [self getLoginItem] != NULL;
}

- (void)setStartAtLogin:(BOOL)doStart
{
    if (doStart) {
        NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
        LSSharedFileListInsertItemURL(loginItems,
                                      kLSSharedFileListItemLast,
                                      NULL,
                                      NULL,
                                      (__bridge CFURLRef)bundleURL,
                                      NULL,
                                      NULL);
    } else {
        LSSharedFileListItemRef loginItemRef = [self getLoginItem];
        if (loginItemRef) {
            LSSharedFileListItemRemove(loginItems, loginItemRef);
            CFRelease(loginItemRef);
        }
        
    }
}

- (LSSharedFileListItemRef)getLoginItem
{
    CFArrayRef snapshotRef = LSSharedFileListCopySnapshot(loginItems, NULL);
    NSURL *bundleURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];
    
    LSSharedFileListItemRef itemRef = NULL;
    CFURLRef itemURLRef;
    
    for (id item in (__bridge NSArray*)snapshotRef) {
        itemRef = (__bridge LSSharedFileListItemRef)item;
        if (LSSharedFileListItemResolve(itemRef, 0, &itemURLRef, NULL) == noErr) {
            if ([bundleURL isEqual:((__bridge NSURL *)itemURLRef)]) {
                CFRetain(itemRef);
                break;
            }
        }
        itemRef = NULL;
    }
    
    CFRelease(snapshotRef);
    return itemRef;
}

static void loginItemsChanged(LSSharedFileListRef listRef, void *context)
{
    HCPreferencesController *controller = (__bridge HCPreferencesController*)context;
    
    [controller willChangeValueForKey:@"startAtLogin"];
    [controller didChangeValueForKey:@"startAtLogin"];
}

#
#pragma mark Teardown
#

- (void)dealloc
{
    LSSharedFileListRemoveObserver(loginItems,
                                   CFRunLoopGetMain(),
                                   kCFRunLoopCommonModes,
                                   loginItemsChanged,
                                   (__bridge void*)self);
    CFRelease(loginItems);
}


@end

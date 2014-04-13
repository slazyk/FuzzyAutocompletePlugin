//
//  LSLFuzzyAutocomplete.m
//  LSLFuzzyAutocomplete
//
//  Created by Jack Chen on 18/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//
//  Extended by Leszek Slazynski.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "LSLFuzzyAutocomplete.h"
#import "LSLFuzzyAutocompleteSettings.h"

@implementation LSLFuzzyAutocomplete

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [NSBundle mainBundle].lsl_bundleName;

    if ([currentApplicationName isEqual:@"Xcode"]) {
        dispatch_once(&onceToken, ^{
            [self createMenuItem: plugin];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self handleConflictingFuzzyAutocompletePlugin];
            });
        });
    }
}

+ (void)tryToRemovePluginBundle: (NSBundle *) bundle {
    NSString * path = bundle.bundlePath;
    NSString * fullName = bundle.lsl_bundleNameWithVersion;
    NSAlert * alert;

    alert = [NSAlert alertWithMessageText: @"Confirmation"
                            defaultButton: @"Cancel"
                          alternateButton: @"Remove"
                              otherButton: nil
                informativeTextWithFormat: @"Are you sure you want to remove %@?\n\n(%@)", fullName, path];

    if ([alert runModal] != NSAlertAlternateReturn) {
        return [self handleConflictingFuzzyAutocompletePlugin];
    } else {
        NSFileManager * manager = [NSFileManager defaultManager];
        NSError * error = nil;
        if ([manager removeItemAtPath:path error:&error]) {
            [[NSAlert alertWithMessageText: @"Success"
                             defaultButton: @"OK"
                           alternateButton: nil
                               otherButton: nil
                 informativeTextWithFormat: @"Plugin removed successfuly.\n\n"
                                             "You must now manually restart Xcode in order to reload plugins."
            ] runModal];
        } else {
            [[NSAlert alertWithError:error] runModal];
        }
    }
}

+ (void)handleConflictingFuzzyAutocompletePlugin {
    // known class in FuzyAutocomplete plugin
    Class class = NSClassFromString(@"FuzzyAutocomplete");
    if (class) {
        NSBundle * conflictingBundle = [NSBundle bundleForClass: class];
        NSBundle * pluginBundle = [NSBundle bundleForClass: self];
        NSString * conflictingFullName = conflictingBundle.lsl_bundleNameWithVersion;
        NSString * pluginFullName = pluginBundle.lsl_bundleNameWithVersion;
        NSAlert * alert;

        // make sure both are xcplugins (just in case)
        if ([conflictingBundle.bundlePath.pathExtension isEqualToString: @"xcplugin"] &&
            [pluginBundle.bundlePath.pathExtension isEqualToString:@"xcplugin"]) {
            alert = [NSAlert alertWithMessageText: @"Conflicting Plugins Detected"
                                    defaultButton: @"Don't remove"
                                  alternateButton: conflictingFullName
                                      otherButton: pluginFullName
                        informativeTextWithFormat: @"Following conflicting plugins have been detected: %@ and %@.\n"
                                                    "If you don't remove one of the plugins neither of them will work properly and Xcode may crash.\n\n"
                                                    "Which of the plugins do you want to remove?", conflictingFullName, pluginFullName];
            NSModalResponse response = [alert runModal];
            if (response == NSAlertAlternateReturn) {
                [self tryToRemovePluginBundle: conflictingBundle];
            } else if (response == NSAlertOtherReturn) {
                [self tryToRemovePluginBundle: pluginBundle];
            } else {
                alert = [NSAlert alertWithMessageText: @"Confirmation"
                                        defaultButton: @"Cancel"
                                      alternateButton: @"Proceed"
                                          otherButton: nil
                            informativeTextWithFormat: @"Are you sure you don't want to remove any of the plugins?\n\n"
                                                        "Neither will work properly and Xcode may crash."];

                if ([alert runModal] != NSAlertAlternateReturn) {
                    return [self handleConflictingFuzzyAutocompletePlugin];
                }
            }
        }
    }
}

+ (void)createMenuItem: (NSBundle *) pluginBundle {
    NSString * name = pluginBundle.lsl_bundleName;
    NSMenuItem *xcodeMenuItem = [[NSApp mainMenu] itemAtIndex: 0];
    NSMenuItem *fuzzyItem = [[NSMenuItem alloc] initWithTitle: name
                                                       action: NULL
                                                keyEquivalent: @""];
    NSString * version = [@"Plugin Version: " stringByAppendingString: pluginBundle.lsl_bundleVersion];
    NSMenuItem * versionItem = [[NSMenuItem alloc] initWithTitle: version
                                                          action: NULL
                                                   keyEquivalent: @""];

    NSMenuItem * settingsItem = [[NSMenuItem alloc] initWithTitle: @"Plugin Settings..."
                                                           action: @selector(showSettingsWindow)
                                                    keyEquivalent: @""];

    settingsItem.target = [LSLFuzzyAutocompleteSettings currentSettings];

    fuzzyItem.submenu = [[NSMenu alloc] initWithTitle: name];
    [fuzzyItem.submenu addItem: versionItem];
    [fuzzyItem.submenu addItem: settingsItem];

    NSInteger menuIndex = [xcodeMenuItem.submenu indexOfItemWithTitle: @"Behaviors"];
    if (menuIndex == -1) {
        menuIndex = 3;
    } else {
        ++menuIndex;
    }

    [xcodeMenuItem.submenu insertItem: fuzzyItem
                              atIndex: menuIndex];
}

@end

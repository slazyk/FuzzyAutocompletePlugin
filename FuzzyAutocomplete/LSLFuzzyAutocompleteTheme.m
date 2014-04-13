//
//  LSLFuzzyAutocompleteTheme.m
//  LSLFuzzyAutocomplete
//
//  Created by Leszek Slazynski on 02/04/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "LSLFuzzyAutocompleteTheme.h"
#import "DVTFontAndColorTheme.h"

@interface LSLFuzzyAutocompleteTheme ()

- (void) loadPreviewAttributesFromTheme: (DVTFontAndColorTheme *) theme;
- (void) loadListAttributesFromTheme: (DVTFontAndColorTheme *) theme;

@property (nonatomic, retain, readwrite) NSColor * listTextColorForScore;
@property (nonatomic, retain, readwrite) NSColor * listTextColorForSelectedScore;
@property (nonatomic, retain, readwrite) NSDictionary * listTextAttributesForMatchedRanges;
@property (nonatomic, retain, readwrite) NSDictionary * previewTextAttributesForNotMatchedRanges;

@end

@implementation LSLFuzzyAutocompleteTheme

+ (instancetype) cuurrentTheme {
    static LSLFuzzyAutocompleteTheme * theme = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        theme = [LSLFuzzyAutocompleteTheme new];
        [theme loadFromTheme: [DVTFontAndColorTheme currentTheme]];
    });
    return theme;
}

- (instancetype) init {
    if ((self = [super init])) {
        DVTFontAndColorTheme * theme = [DVTFontAndColorTheme currentTheme];
        [self loadFromTheme: theme];
    }
    return self;
}

- (void)loadFromTheme:(DVTFontAndColorTheme *)theme {
    [self loadPreviewAttributesFromTheme: theme];
    [self loadListAttributesFromTheme: theme];
}

- (void) loadPreviewAttributesFromTheme: (DVTFontAndColorTheme *) theme {
    self.previewTextAttributesForNotMatchedRanges = @{
        NSForegroundColorAttributeName  : theme.sourceTextCompletionPreviewColor,
    };
}

- (void) loadListAttributesFromTheme:(DVTFontAndColorTheme *)theme {
    NSColor * color = [NSColor colorWithCalibratedRed:0.886 green:0.777 blue:0.045 alpha:1.000];
    self.listTextAttributesForMatchedRanges = @{
        NSUnderlineStyleAttributeName   : @1,
        NSBackgroundColorAttributeName  : [color colorWithAlphaComponent: 0.25],
        NSUnderlineColorAttributeName   : color,
    };

    self.listTextColorForScore = [NSColor colorWithCalibratedRed:0.497 green:0.533 blue:0.993 alpha:1.000];
    self.listTextColorForSelectedScore = [NSColor colorWithCalibratedRed:0.838 green:0.850 blue:1.000 alpha:1.000];
}

@end

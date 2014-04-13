//
//  LSLFuzzyAutocompleteTheme.h
//  LSLFuzzyAutocomplete
//
//  Created by Leszek Slazynski on 02/04/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DVTFontAndColorTheme;

@interface LSLFuzzyAutocompleteTheme : NSObject

+ (instancetype) cuurrentTheme;

- (void) loadFromTheme: (DVTFontAndColorTheme *) theme;

@property (nonatomic, retain, readonly) NSColor * listTextColorForScore;
@property (nonatomic, retain, readonly) NSColor * listTextColorForSelectedScore;

@property (nonatomic, retain, readonly) NSDictionary * listTextAttributesForMatchedRanges;

@property (nonatomic, retain, readonly) NSDictionary * previewTextAttributesForNotMatchedRanges;

@end

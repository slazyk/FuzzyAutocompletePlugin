//
//  DVTTextCompletionInlinePreviewController+LSLFuzzyAutocomplete.m
//  LSLFuzzyAutocomplete
//
//  Created by Leszek Slazynski on 03/02/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionInlinePreviewController+LSLFuzzyAutocomplete.h"
#import "DVTTextCompletionSession.h"
#import "DVTTextCompletionSession+LSLFuzzyAutocomplete.h"
#import "DVTFontAndColorTheme.h"
#import "JRSwizzle.h"
#import <objc/runtime.h>

@implementation DVTTextCompletionInlinePreviewController (LSLFuzzyAutocomplete)

+ (void)load {
    [self jr_swizzleMethod: @selector(ghostComplementRange)
                withMethod: @selector(_lslfa_ghostComplementRange)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_showPreviewForItem:)
                withMethod: @selector(_lslfa_showPreviewForItem:)
                     error: NULL];
}

#pragma mark - overrides

// We added calculation of matchedRanges and ghostRange here.
- (void) _lslfa_showPreviewForItem: (id<DVTTextCompletionItem>) item {
    [self _lslfa_showPreviewForItem: item];

    DVTTextCompletionSession * session = [self valueForKey: @"_session"];

    NSArray * ranges = [session lslfa_matchedRangesForItem: item];

    if (!ranges.count) {
        self.lslfa_matchedRanges = nil;
        self.lslfa_overridedGhostRange = nil;
        return;
    }

    NSUInteger previewLength = self.previewRange.length;
    NSString *previewText;

    if (previewLength == item.completionText.length) {
        previewText = item.completionText;
    } else if (previewLength == item.name.length) {
        previewText = item.name;
    } else if (previewLength == item.displayText.length) {
        previewText = item.displayText;
    } else {
        NSTextView * textView = (NSTextView *) session.textView;
        previewText = [[textView.textStorage attributedSubstringFromRange: self.previewRange] string];
    }

    ranges = [session lslfa_convertRanges: ranges
                               fromString: item.name
                                 toString: previewText
                                addOffset: self.previewRange.location];

    if (!ranges.count) {
        self.lslfa_overridedGhostRange = nil;
    } else {
        NSRange lastRange = [[ranges lastObject] rangeValue];
        NSUInteger start = NSMaxRange(lastRange);
        NSUInteger end = NSMaxRange(self.previewRange);
        NSRange override = NSMakeRange(start, end - start);
        self.lslfa_overridedGhostRange = [NSValue valueWithRange: override];
    }

    self.lslfa_matchedRanges = ranges;
}

- (NSRange) _lslfa_ghostComplementRange {
    NSValue * override = self.lslfa_overridedGhostRange;
    if (override) {
        return [override rangeValue];
    }
    return [self _lslfa_ghostComplementRange];
}

#pragma mark - additional properties

static char overrideGhostKey;
static char matchedRangesKey;

- (NSArray *)lslfa_matchedRanges {
    return objc_getAssociatedObject(self, &matchedRangesKey);
}

- (void)setLslfa_matchedRanges:(NSArray *)array {
    objc_setAssociatedObject(self, &matchedRangesKey, array, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// We override the gost range to span only after last matched letter.
// This way we do not need to apply arguments to matched ranges.
- (NSValue *)lslfa_overridedGhostRange {
    return objc_getAssociatedObject(self, &overrideGhostKey);
}

- (void)setLslfa_overridedGhostRange:(NSValue *)value {
    objc_setAssociatedObject(self, &overrideGhostKey, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

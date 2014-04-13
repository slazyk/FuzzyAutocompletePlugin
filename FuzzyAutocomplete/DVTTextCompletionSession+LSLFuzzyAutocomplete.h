//
//  DVTTextCompletionSession+LSLFuzzyAutocomplete.h
//  LSLFuzzyAutocomplete
//
//  Created by Jack Chen on 19/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//
//  Extended by Leszek Slazynski.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionSession.h"

@protocol DVTTextCompletionItem;

@interface DVTTextCompletionSession (LSLFuzzyAutocomplete)

/// Current filtering query.
- (NSString *) lslfa_filteringQuery;

/// Time (in seconds) spent on last filtering operation.
- (NSTimeInterval) lslfa_lastFilteringTime;

/// Number of items with non-zero scores.
- (NSUInteger) lslfa_nonZeroScores;

/// Gets array of ranges matched by current search string in given items name.
- (NSArray *) lslfa_matchedRangesForItem: (id<DVTTextCompletionItem>) item;

/// Retrieves a previously calculated autocompletion score for given item.
- (NSNumber *) lslfa_scoreForItem: (id<DVTTextCompletionItem>) item;

/// Try to convert ranges ocurring in fromString into toString.
/// Optionally offsets the resulting ranges.
///
/// Handled cases:
///
/// a) fromString is a substring of toString
///
/// b) both fromString and toString contain segments ending with colons
- (NSArray *) lslfa_convertRanges: (NSArray *) originalRanges
                       fromString: (NSString *) fromString
                         toString: (NSString *) toString
                        addOffset: (NSUInteger) additionalOffset;



@end

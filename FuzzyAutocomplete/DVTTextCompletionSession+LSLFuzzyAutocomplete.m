//  DVTTextCompletionSession+LSLFuzzyAutocomplete.m
//  LSLFuzzyAutocomplete
//
//  Created by Jack Chen on 19/10/2013.
//  Copyright (c) 2013 Sproutcube. All rights reserved.
//
//  Extended by Leszek Slazynski.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionSession+LSLFuzzyAutocomplete.h"
#import "DVTTextCompletionInlinePreviewController.h"
#import "DVTTextCompletionInlinePreviewController+LSLFuzzyAutocomplete.h"
#import "DVTTextCompletionListWindowController.h"
#import "IDEOpenQuicklyPattern.h"
#import "LSLFuzzyAutocompleteTheme.h"
#import "DVTFontAndColorTheme.h"
#import "JRSwizzle.h"
#import "LSLFuzzyAutocompleteSettings.h"
#import "LSLItemScoringMethod.h"
#import <objc/runtime.h>

#define MIN_CHUNK_LENGTH 100

@implementation DVTTextCompletionSession (LSLFuzzyAutocomplete)

+ (void) load {
    [self jr_swizzleMethod: @selector(_setFilteringPrefix:forceFilter:)
                withMethod: @selector(_lslfa_setFilteringPrefix:forceFilter:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(setAllCompletions:)
                withMethod: @selector(_lslfa_setAllCompletions:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_usefulPartialCompletionPrefixForItems:selectedIndex:filteringPrefix:)
                withMethod: @selector(_lslfa_usefulPartialCompletionPrefixForItems:selectedIndex:filteringPrefix:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(attributesForCompletionAtCharacterIndex:effectiveRange:)
                withMethod: @selector(_lslfa_attributesForCompletionAtCharacterIndex:effectiveRange:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(rangeOfFirstWordInString:)
                withMethod: @selector(_lslfa_rangeOfFirstWordInString:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(initWithTextView:atLocation:cursorLocation:)
                withMethod: @selector(lslfa_initWithTextView:atLocation:cursorLocation:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(insertCurrentCompletion)
                withMethod: @selector(lslfa_insertCurrentCompletion)
                     error: nil];    
}

#pragma mark - public methods

- (NSArray *) lslfa_convertRanges: (NSArray *) originalRanges
                       fromString: (NSString *) fromString
                         toString: (NSString *) toString
                        addOffset: (NSUInteger) additionalOffset
{
    NSMutableArray * newRanges = [NSMutableArray array];
    NSRange base = [toString rangeOfString: fromString];
    if (base.location != NSNotFound) {
        for (NSValue * value in originalRanges) {
            NSRange range = [value rangeValue];
            range.location += base.location + additionalOffset;
            [newRanges addObject: [NSValue valueWithRange: range]];
        }
    } else {
        // TODO: consider changing to componentsSeparatedByString: for performance (?)
        NSRegularExpression * selectorSegmentRegex = [NSRegularExpression regularExpressionWithPattern: @"[a-zA-Z_][a-zA-Z0-9_]*:" options: 0 error: NULL];
        [selectorSegmentRegex enumerateMatchesInString: fromString options: 0 range: NSMakeRange(0, fromString.length) usingBlock:^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop) {
            NSRange nameRange = result.range;
            NSRange dispRange = [toString rangeOfString: [fromString substringWithRange: nameRange]];
            if (dispRange.location != NSNotFound) {
                for (NSValue * value in originalRanges) {
                    NSRange range = [value rangeValue];
                    NSRange intersection = NSIntersectionRange(range, nameRange);
                    if (intersection.length > 0) {
                        intersection.location += dispRange.location - nameRange.location + additionalOffset;
                        [newRanges addObject: [NSValue valueWithRange: intersection]];
                    }
                }
            }
        }];
    }
    return newRanges;
}

- (NSArray *) lslfa_matchedRangesForItem: (id<DVTTextCompletionItem>) item {
    return [[self lslfa_matchedRangesForFilteredCompletions] objectForKey: item.name];
}

- (NSNumber *) lslfa_scoreForItem: (id<DVTTextCompletionItem>) item {
    return [[self lslfa_scoresForFilteredCompletions] objectForKey: item.name];
}

- (NSUInteger)lslfa_nonZeroScores {
    return [self lslfa_scoresForFilteredCompletions].count;
}

#pragma mark - overrides

- (BOOL)lslfa_insertCurrentCompletion {
    self.lslfa_insertingCompletion = YES;
    BOOL ret = [self lslfa_insertCurrentCompletion];
    self.lslfa_insertingCompletion = NO;
    return ret;
}

// We additionally refresh the theme upon session creation.
- (instancetype) lslfa_initWithTextView: (NSTextView *) textView
                             atLocation: (NSInteger) location
                         cursorLocation: (NSInteger) cursorLocation
{
    [[LSLFuzzyAutocompleteSettings currentSettings] loadFromDefaults];
    [[LSLFuzzyAutocompleteTheme cuurrentTheme] loadFromTheme: [DVTFontAndColorTheme currentTheme]];
    DVTTextCompletionSession * session = [self lslfa_initWithTextView:textView atLocation:location cursorLocation:cursorLocation];
    if (session) {
        LSLItemScoringMethod * method = [[LSLItemScoringMethod alloc] init];
        LSLFuzzyAutocompleteSettings * settings = [LSLFuzzyAutocompleteSettings currentSettings];

        method.matchScorePower = settings.matchScorePower;
        method.priorityFactorPower = settings.priorityFactorPower;
        method.priorityPower = settings.priorityPower;
        method.maxPrefixBonus = settings.maxPrefixBonus;

        session._lslfa_currentScoringMethod = method;
    }
    return session;
}

// Based on the first word, either completionString or name is used for preview.
// We override in such a way that the name is always used.
// Otherwise the cursor can be possibly placed inside a token.
- (NSRange) _lslfa_rangeOfFirstWordInString: (NSString *) string {
    return NSMakeRange(0, string.length);
}

// We override to add formatting to the inline preview.
// The ghostCompletionRange is also overriden to be after the last matched letter.
- (NSDictionary *) _lslfa_attributesForCompletionAtCharacterIndex: (NSUInteger) index
                                                   effectiveRange: (NSRange *) effectiveRange
{
    NSDictionary * ret = [self _lslfa_attributesForCompletionAtCharacterIndex:index effectiveRange:effectiveRange];

    if ([self._inlinePreviewController isShowingInlinePreview]) {
        if (NSLocationInRange(index, [self._inlinePreviewController previewRange])) {
            *effectiveRange = ret ? NSIntersectionRange(*effectiveRange, [self._inlinePreviewController previewRange]) : [self._inlinePreviewController previewRange];
            BOOL matched = NO;
            for (NSValue * val in [self._inlinePreviewController lslfa_matchedRanges]) {
                NSRange range = [val rangeValue];
                if (NSLocationInRange(index, range)) {
                    matched = YES;
                    *effectiveRange = NSIntersectionRange(range, *effectiveRange);
                    break;
                } else if (range.location > index) {
                    *effectiveRange = NSIntersectionRange(NSMakeRange(index, range.location - index), *effectiveRange);
                    break;
                }
            }
            if (!matched) {
                NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithDictionary: ret];
                [dict addEntriesFromDictionary: [LSLFuzzyAutocompleteTheme cuurrentTheme].previewTextAttributesForNotMatchedRanges];
                ret = dict;
            }
        }
    }
    return ret;
}

// We replace the search string by a prefix to the last matched letter.
- (NSString *) _lslfa_usefulPartialCompletionPrefixForItems: (NSArray *) items
                                           selectedIndex: (NSInteger) index
                                         filteringPrefix: (NSString *) prefix
{
    if (!items.count || index == NSNotFound || index > items.count) {
        return nil;
    }
    NSRange range = NSMakeRange(0, prefix.length);
    id<DVTTextCompletionItem> item = items[index];
    NSArray * ranges = [[[IDEOpenQuicklyPattern alloc] initWithPattern: prefix] matchedRanges: item.name];
    for (NSValue * val in ranges) {
        range = NSUnionRange(range, [val rangeValue]);
    }
    return [self _lslfa_usefulPartialCompletionPrefixForItems:items selectedIndex:index filteringPrefix:[item.name substringWithRange: range]];
}

// Sets the current filtering prefix and calculates completion list.
// We override here to use fuzzy matching.
- (void)_lslfa_setFilteringPrefix: (NSString *) prefix forceFilter: (BOOL) forceFilter { MARK
    DLog(@"filteringPrefix = @\"%@\"", prefix);

    self.lslfa_filteringTime = 0;

    NSString *lastPrefix = [self valueForKey: @"_filteringPrefix"];

    // Let the original handler deal with the zero letter case
    if (prefix.length == 0) {
        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

        self.lslfa_matchedRangesForFilteredCompletions = nil;
        self.lslfa_scoresForFilteredCompletions = nil;
        [self _lslfa_setFilteringPrefix:prefix forceFilter:forceFilter];
        if (![LSLFuzzyAutocompleteSettings currentSettings].showInlinePreview) {
            [self._inlinePreviewController hideInlinePreviewWithReason: 0x0];
        }

        self.lslfa_filteringTime = [NSDate timeIntervalSinceReferenceDate] - start;

        if ([LSLFuzzyAutocompleteSettings currentSettings].showTiming) {
            [self._listWindowController _updateCurrentDisplayState];
        }

        return;
    }

    // do not filter if we are inserting a completion
    // checking for _insertingFullCompletion is not sufficient
    if (self.lslfa_insertingCompletion) {
        return;
    }

    @try {

        NSTimeInterval start = [NSDate timeIntervalSinceReferenceDate];

        NSArray *searchSet = nil;

        [self setValue: prefix forKey: @"_filteringPrefix"];

        const NSInteger anchor = [LSLFuzzyAutocompleteSettings currentSettings].anchorLength;

        NAMED_TIMER_START(ObtainSearchSet);

        if (lastPrefix && [[prefix lowercaseString] hasPrefix: [lastPrefix lowercaseString]]) {
            if (lastPrefix.length >= anchor) {
                searchSet = self.lslfa_nonZeroMatches;
            } else {
                searchSet = [self _lslfa_filteredCompletionsForPrefix: [prefix substringToIndex: MIN(prefix.length, anchor)]];
            }
        } else {
            if (anchor > 0) {
                searchSet = [self _lslfa_filteredCompletionsForPrefix: [prefix substringToIndex: MIN(prefix.length, anchor)]];
            } else {
                searchSet = [self _lslfa_filteredCompletionsForLetter: [prefix substringToIndex:1]];
            }
        }

        NAMED_TIMER_STOP(ObtainSearchSet);

        NSMutableArray * filteredList;
        NSMutableDictionary *filteredRanges;
        NSMutableDictionary *filteredScores;

        __block id<DVTTextCompletionItem> bestMatch = nil;

        NSUInteger workerCount = MIN(MAX(searchSet.count / MIN_CHUNK_LENGTH, 1), [self maxWorkerCount]);

        NAMED_TIMER_START(CalculateScores);

        if (workerCount < 2) {
            bestMatch = [self _lslfa_bestMatchForQuery: prefix
                                               inArray: searchSet
                                          filteredList: &filteredList
                                             rangesMap: &filteredRanges
                                                scores: &filteredScores];
        } else {
            dispatch_queue_t processingQueue = dispatch_queue_create("LSLFuzzyAutocomplete.processing-queue", DISPATCH_QUEUE_CONCURRENT);
            dispatch_queue_t reduceQueue = dispatch_queue_create("LSLFuzzyAutocomplete.reduce-queue", DISPATCH_QUEUE_SERIAL);
            dispatch_group_t group = dispatch_group_create();

            NSMutableArray *bestMatches = [NSMutableArray array];
            filteredList = [NSMutableArray array];
            filteredRanges = [NSMutableDictionary dictionary];
            filteredScores = [NSMutableDictionary dictionary];

            for (NSInteger i = 0; i < workerCount; ++i) {
                dispatch_group_async(group, processingQueue, ^{
                    NSArray *list;
                    NSDictionary *rangesMap;
                    NSDictionary *scoresMap;
                    NAMED_TIMER_START(Processing);
                    id<DVTTextCompletionItem> bestMatch = [self _lslfa_bestMatchForQuery: prefix
                                                                            inArray: searchSet
                                                                             offset: i
                                                                              total: workerCount
                                                                       filteredList: &list
                                                                          rangesMap: &rangesMap
                                                                             scores: &scoresMap];
                    NAMED_TIMER_STOP(Processing);
                    dispatch_async(reduceQueue, ^{
                        NAMED_TIMER_START(Reduce);
                        if (bestMatch) {
                            [bestMatches addObject:bestMatch];
                        }
                        [filteredList addObjectsFromArray:list];
                        [filteredRanges addEntriesFromDictionary:rangesMap];
                        [filteredScores addEntriesFromDictionary:scoresMap];
                        NAMED_TIMER_STOP(Reduce);
                    });
                });
            }

            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
            dispatch_sync(reduceQueue, ^{});

            bestMatch = [self _lslfa_bestMatchForQuery: prefix
                                               inArray: bestMatches
                                          filteredList: nil
                                             rangesMap: nil
                                                scores: nil];

        }

        NAMED_TIMER_STOP(CalculateScores);

        if ([LSLFuzzyAutocompleteSettings currentSettings].showInlinePreview) {
            if ([self._inlinePreviewController isShowingInlinePreview]) {
                [self._inlinePreviewController hideInlinePreviewWithReason:0x8];
            }
        }

        // setter copies the array
        self.lslfa_nonZeroMatches = filteredList;

        NAMED_TIMER_START(FilterByScore);

        double threshold = [LSLFuzzyAutocompleteSettings currentSettings].minimumScoreThreshold;
        if ([LSLFuzzyAutocompleteSettings currentSettings].filterByScore && threshold != 0) {
            if ([LSLFuzzyAutocompleteSettings currentSettings].normalizeScores) {
                threshold *= [filteredScores[bestMatch.name] doubleValue];
            }
            NSMutableArray * newArray = [NSMutableArray array];
            for (id<DVTTextCompletionItem> item in filteredList) {
                if ([filteredScores[item.name] doubleValue] >= threshold) {
                    [newArray addObject: item];
                }
            }
            filteredList = newArray;
        }

        NAMED_TIMER_STOP(FilterByScore);

        NAMED_TIMER_START(SortByScore);

        if ([LSLFuzzyAutocompleteSettings currentSettings].sortByScore) {
            [filteredList sortWithOptions: NSSortConcurrent usingComparator:^(id<DVTTextCompletionItem> obj1, id<DVTTextCompletionItem> obj2) {
                return [filteredScores[obj2.name] compare: filteredScores[obj1.name]];
            }];
        }

        NAMED_TIMER_STOP(SortByScore);

        NAMED_TIMER_START(FindSelection);

        NSUInteger selection = filteredList.count && bestMatch ? [filteredList indexOfObject:bestMatch] : NSNotFound;

        NAMED_TIMER_STOP(FindSelection);

        [self setPendingRequestState: 0];

        NSString * partial = [self _usefulPartialCompletionPrefixForItems: filteredList selectedIndex: selection filteringPrefix: prefix];

        self.lslfa_matchedRangesForFilteredCompletions = filteredRanges;
        self.lslfa_scoresForFilteredCompletions = filteredScores;

        self.lslfa_filteringTime = [NSDate timeIntervalSinceReferenceDate] - start;

        NAMED_TIMER_START(SendNotifications);

        // send the notifications in the same way the original does
        [self willChangeValueForKey:@"filteredCompletionsAlpha"];
        [self willChangeValueForKey:@"usefulPrefix"];
        [self willChangeValueForKey:@"selectedCompletionIndex"];
        
        [self setValue: filteredList forKey: @"_filteredCompletionsAlpha"];
        [self setValue: partial forKey: @"_usefulPrefix"];
        [self setValue: @(selection) forKey: @"_selectedCompletionIndex"];
        
        [self didChangeValueForKey:@"filteredCompletionsAlpha"];
        [self didChangeValueForKey:@"usefulPrefix"];
        [self didChangeValueForKey:@"selectedCompletionIndex"];

        NAMED_TIMER_STOP(SendNotifications);

        if (![LSLFuzzyAutocompleteSettings currentSettings].showInlinePreview) {
            [self._inlinePreviewController hideInlinePreviewWithReason: 0x0];
        }

    }
    @catch (NSException *exception) {
        RLog(@"Caught an Exception %@", exception);
    }
    @finally {
        
    }
    
}

static char letterFilteredCompletionCacheKey;
static char prefixFilteredCompletionCacheKey;

// We nullify the caches when completions change.
- (void) _lslfa_setAllCompletions: (NSArray *) allCompletions {
    [self _lslfa_setAllCompletions:allCompletions];
    self.lslfa_matchedRangesForFilteredCompletions = nil;
    self.lslfa_scoresForFilteredCompletions = nil;
    [objc_getAssociatedObject(self, &letterFilteredCompletionCacheKey) removeAllObjects];
    [objc_getAssociatedObject(self, &prefixFilteredCompletionCacheKey) removeAllObjects];
}

#pragma mark - helpers

// Score the items, store filtered list, matched ranges, scores and the best match.
- (id<DVTTextCompletionItem>) _lslfa_bestMatchForQuery: (NSString *) query
                                              inArray: (NSArray *) array
                                         filteredList: (NSArray **) filtered
                                            rangesMap: (NSDictionary **) ranges
                                               scores: (NSDictionary **) scores
{
    return [self _lslfa_bestMatchForQuery:query inArray:array offset:0 total:1 filteredList:filtered rangesMap:ranges scores:scores];
}

// Score some of the items, store filtered list, matched ranges, scores and the best match.
- (id<DVTTextCompletionItem>) _lslfa_bestMatchForQuery: (NSString *) query
                                              inArray: (NSArray *) array
                                               offset: (NSUInteger) offset
                                                total: (NSUInteger) total
                                         filteredList: (NSArray **) filtered
                                            rangesMap: (NSDictionary **) ranges
                                               scores: (NSDictionary **) scores
{
    IDEOpenQuicklyPattern *pattern = [[IDEOpenQuicklyPattern alloc] initWithPattern:query];
    NSMutableArray *filteredList = filtered ? [NSMutableArray arrayWithCapacity: array.count] : nil;
    NSMutableDictionary *filteredRanges = ranges ? [NSMutableDictionary dictionaryWithCapacity: array.count] : nil;
    NSMutableDictionary *filteredScores = scores ? [NSMutableDictionary dictionaryWithCapacity: array.count] : nil;

    double highScore = 0.0f;
    id<DVTTextCompletionItem> bestMatch;

    LSLItemScoringMethod * method = self._lslfa_currentScoringMethod;

    double normalization = [method normalizationFactorForSearchString: query];

    id<DVTTextCompletionItem> item;
    NSUInteger lower_bound = offset * (array.count / total);
    NSUInteger upper_bound = offset == total - 1 ? array.count : (offset + 1) * (array.count / total);

    DLog(@"Process elements %lu %lu (%lu)", lower_bound, upper_bound, array.count);

    MULTI_TIMER_INIT(Matching); MULTI_TIMER_INIT(Scoring); MULTI_TIMER_INIT(Writing);

    for (NSUInteger i = lower_bound; i < upper_bound; ++i) {
        item = array[i];
        NSArray * rangesArray;
        double matchScore;

        MULTI_TIMER_START(Matching);
        if (query.length == 1) {
            NSRange range = [item.name rangeOfString: query options: NSCaseInsensitiveSearch];
            if (range.location != NSNotFound) {
                rangesArray = @[ [NSValue valueWithRange:range] ];
                matchScore = MAX(0.001, [pattern scoreCandidate:item.name matchedRanges:&rangesArray]);
            } else {
                matchScore = 0;
            }
        } else {
            matchScore = [pattern scoreCandidate:item.name matchedRanges:&rangesArray];
        }
        MULTI_TIMER_STOP(Matching);

        if (matchScore > 0) {
            MULTI_TIMER_START(Scoring);
            double factor = [self _priorityFactorForItem:item];
            double score = normalization * [method scoreItem: item
                                                searchString: query
                                                  matchScore: matchScore
                                               matchedRanges: rangesArray
                                              priorityFactor: factor];
            MULTI_TIMER_STOP(Scoring);
            MULTI_TIMER_START(Writing);
            if (score > 0) {
                [filteredList addObject:item];
                filteredRanges[item.name] = rangesArray;
                filteredScores[item.name] = @(score);
            }
            if (score > highScore) {
                bestMatch = item;
                highScore = score;
            }
            MULTI_TIMER_STOP(Writing);
        }
    }

    DLog(@"Matching %f | Scoring %f | Writing %f", MULTI_TIMER_GET(Matching), MULTI_TIMER_GET(Scoring), MULTI_TIMER_GET(Writing));

    if (filtered) {
        *filtered = filteredList;
    }
    if (ranges) {
        *ranges = filteredRanges;
    }
    if (scores) {
        *scores = filteredScores;
    }
    return bestMatch;
}

// Performs a simple binary search to find rirst item with iven prefix.
- (NSInteger) _lslfa_indexOfFirstItemWithPrefix: (NSString *) prefix inSortedArray: (NSArray *) array {
    const NSUInteger N = array.count;

    if (N == 0) return NSNotFound;

    id<DVTTextCompletionItem> item;

    if ([(item = array[0]).name compare: prefix options: NSCaseInsensitiveSearch] == NSOrderedDescending) {
        if ([[item.name lowercaseString] hasPrefix: prefix]) {
            return 0;
        } else {
            return NSNotFound;
        }
    }

    if ([(item = array[N-1]).name compare: prefix options: NSCaseInsensitiveSearch] == NSOrderedAscending) {
        return NSNotFound;
    }

    NSUInteger a = 0, b = N-1;
    while (b > a+1) {
        NSUInteger c = (a + b) / 2;
        if ([(item = array[c]).name compare: prefix options: NSCaseInsensitiveSearch] == NSOrderedAscending) {
            a = c;
        } else {
            b = c;
        }
    }

    if ([[(item = array[a]).name lowercaseString] hasPrefix: prefix]) {
        return a;
    }
    if ([[(item = array[b]).name lowercaseString] hasPrefix: prefix]) {
        return b;
    }

    return NSNotFound;
}

// gets a subset of allCompletions for given prefix
- (NSArray *) _lslfa_filteredCompletionsForPrefix: (NSString *) prefix {
    prefix = [prefix lowercaseString];
    NSMutableDictionary *filteredCompletionCache = objc_getAssociatedObject(self, &prefixFilteredCompletionCacheKey);
    if (!filteredCompletionCache) {
        filteredCompletionCache = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &prefixFilteredCompletionCacheKey, filteredCompletionCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray *completionsForPrefix = filteredCompletionCache[prefix];
    if (!completionsForPrefix) {
        NSArray * searchSet = self.allCompletions;
        for (int i = 1; i < prefix.length; ++i) {
            NSArray * cached = filteredCompletionCache[[prefix substringToIndex: i]];
            if (cached) {
                searchSet = cached;
            }
        }
        // searchSet is sorted so we can do a binary search
        NSUInteger idx = [self _lslfa_indexOfFirstItemWithPrefix: prefix inSortedArray: searchSet];
        if (idx == NSNotFound) {
            completionsForPrefix = @[];
        } else {
            NSMutableArray * array = [NSMutableArray array];
            const NSUInteger N = searchSet.count;
            id<DVTTextCompletionItem> item;
            while (idx < N && [(item = searchSet[idx]).name.lowercaseString hasPrefix: prefix]) {
                [array addObject: item];
                ++idx;
            }
            completionsForPrefix = array;
        }
    }
    return completionsForPrefix;
}

// gets a subset of allCompletions for given letter
- (NSArray *) _lslfa_filteredCompletionsForLetter: (NSString *) letter {
    letter = [letter lowercaseString];
    NSMutableDictionary *filteredCompletionCache = objc_getAssociatedObject(self, &letterFilteredCompletionCacheKey);
    if (!filteredCompletionCache) {
        filteredCompletionCache = [NSMutableDictionary dictionary];
        objc_setAssociatedObject(self, &letterFilteredCompletionCacheKey, filteredCompletionCache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSArray *completionsForLetter = [filteredCompletionCache objectForKey:letter];
    if (!completionsForLetter) {
        NSString * lowerAndUpper = [letter stringByAppendingString: letter.uppercaseString];
        NSCharacterSet * set = [NSCharacterSet characterSetWithCharactersInString: lowerAndUpper];
        NSMutableArray * array = [NSMutableArray array];
        for (id<DVTTextCompletionItem> item in self.allCompletions) {
            NSRange range = [item.name rangeOfCharacterFromSet: set];
            if (range.location != NSNotFound) {
                [array addObject: item];
            }
        }
        completionsForLetter = array;
        filteredCompletionCache[letter] = completionsForLetter;
    }
    return completionsForLetter;
}

- (void)_lslfa_debugCompletionsByScore:(NSArray *)completions withQuery:(NSString *)query {
    IDEOpenQuicklyPattern *pattern = [IDEOpenQuicklyPattern patternWithInput:query];
    NSMutableArray *completionsWithScore = [NSMutableArray arrayWithCapacity:completions.count];

    [completions enumerateObjectsUsingBlock:^(id<DVTTextCompletionItem> item, NSUInteger idx, BOOL *stop) {
        NSArray * ranges = nil;
        double matchScore = [pattern scoreCandidate: item.name matchedRanges: &ranges];
        double factor = [self _priorityFactorForItem: item];
        [completionsWithScore addObject:@{
            @"item"       : item.name,
            @"ranges"     : ranges ? ranges : @[],
            @"factor"     : @(factor),
            @"priority"   : @(item.priority),
            @"matchScore" : @(matchScore),
            @"score"      : @([self._lslfa_currentScoringMethod scoreItem: item searchString: query matchScore: matchScore matchedRanges: ranges priorityFactor: factor])
        }];
    }];

    NSSortDescriptor *sortByScore = [NSSortDescriptor sortDescriptorWithKey:@"score" ascending:NO];

    [completionsWithScore sortUsingDescriptors:@[sortByScore]];
    
    [completionsWithScore enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        RLog(@"%lu - %@", idx + 1, obj);
        if (idx == 24) *stop = YES;
    }];

}

#pragma mark - properties

- (NSUInteger) maxWorkerCount {
    return [LSLFuzzyAutocompleteSettings currentSettings].parallelScoring ? [LSLFuzzyAutocompleteSettings currentSettings].maximumWorkers : 1;
}

- (NSString *)lslfa_filteringQuery {
    return [self valueForKey: @"_filteringPrefix"];
}

static char kTimeKey;
- (NSTimeInterval)lslfa_lastFilteringTime {
    return [objc_getAssociatedObject(self, &kTimeKey) doubleValue];
}

- (void)setLslfa_filteringTime:(NSTimeInterval)value {
    objc_setAssociatedObject(self, &kTimeKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char currentScoringMethodKey;

- (LSLItemScoringMethod *) _lslfa_currentScoringMethod {
    return objc_getAssociatedObject(self, &currentScoringMethodKey);
}

- (void) set_lslfa_currentScoringMethod: (LSLItemScoringMethod *) value {
    objc_setAssociatedObject(self, &currentScoringMethodKey, value, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char insertingCompletionKey;

- (BOOL) lslfa_insertingCompletion {
    return [objc_getAssociatedObject(self, &insertingCompletionKey) boolValue];
}

- (void) setLslfa_insertingCompletion: (BOOL) value {
    objc_setAssociatedObject(self, &insertingCompletionKey, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char matchedRangesKey;

- (NSDictionary *) lslfa_matchedRangesForFilteredCompletions {
    return objc_getAssociatedObject(self, &matchedRangesKey);
}

- (void) setLslfa_matchedRangesForFilteredCompletions: (NSDictionary *) dict {
    objc_setAssociatedObject(self, &matchedRangesKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static char scoresKey;

- (void) setLslfa_scoresForFilteredCompletions: (NSDictionary *) dict {
    objc_setAssociatedObject(self, &scoresKey, dict, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSDictionary *) lslfa_scoresForFilteredCompletions {
    return objc_getAssociatedObject(self, &scoresKey);
}

static char kNonZeroMatchesKey;

- (NSArray *) lslfa_nonZeroMatches {
    return objc_getAssociatedObject(self, &kNonZeroMatchesKey);
}

- (void) setLslfa_nonZeroMatches: (NSArray *) array {
    objc_setAssociatedObject(self, &kNonZeroMatchesKey, array, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

//
//  DVTTextCompletionInlinePreviewController+LSLFuzzyAutocomplete.h
//  LSLFuzzyAutocomplete
//
//  Created by Leszek Slazynski on 03/02/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionInlinePreviewController.h"

@interface DVTTextCompletionInlinePreviewController (LSLFuzzyAutocomplete)

/// Matched ranges mapped to preview space.
@property (nonatomic, retain) NSArray * lslfa_matchedRanges;

@end

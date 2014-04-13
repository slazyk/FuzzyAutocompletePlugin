//
//  DVTTextCompletionListWindowController+LSLFuzzyAutocomplete.m
//  LSLFuzzyAutocomplete
//
//  Created by Leszek Slazynski on 01/02/2014.
//  Copyright (c) 2014 United Lines of Code. All rights reserved.
//

#import "DVTTextCompletionListWindowController+LSLFuzzyAutocomplete.h"
#import "DVTTextCompletionItem-Protocol.h"
#import "DVTTextCompletionSession.h"
#import "DVTTextCompletionSession+LSLFuzzyAutocomplete.h"
#import "LSLFuzzyAutocompleteTheme.h"
#import "JRSwizzle.h"
#import "LSLFuzzyAutocompleteSettings.h"
#import "LSLTextCompletionListHeaderView.h"
#import "DVTFontAndColorTheme.h"
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

@implementation DVTTextCompletionListWindowController (LSLFuzzyAutocomplete)

+ (void) load {
    [self jr_swizzleMethod: @selector(tableView:willDisplayCell:forTableColumn:row:)
                withMethod: @selector(_lslfa_tableView:willDisplayCell:forTableColumn:row:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(tableView:objectValueForTableColumn:row:)
                withMethod: @selector(lslfa_tableView:valueForColumn:row:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_getTitleColumnWidth:typeColumnWidth:)
                withMethod: @selector(_lslfa_getTitleColumnWidth:typeColumnWidth:)
                     error: NULL];

    [self jr_swizzleMethod: @selector(windowDidLoad)
                withMethod: @selector(lslfa_windowDidLoad)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_updateCurrentDisplayState)
                withMethod: @selector(_lslfa_updateCurrentDisplayState)
                     error: NULL];

    [self jr_swizzleMethod: @selector(_updateCurrentDisplayStateForQuickHelp)
                withMethod: @selector(_lslfa_updateCurrentDisplayStateForQuickHelp)
                     error: NULL];
}

#pragma mark - overrides

const char kRowHeightKey;

// We (optionally) add a score column and a header.
- (void) lslfa_windowDidLoad {
    [self lslfa_windowDidLoad];

    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];

    if ([LSLFuzzyAutocompleteSettings currentSettings].showListHeader) {
        tableView.headerView = [[LSLTextCompletionListHeaderView alloc] initWithFrame: NSMakeRect(0, 0, 100, 22)];
        tableView.cornerView = [[LSLTextCompletionListCornerView alloc] initWithFrame: NSMakeRect(0, 0, 22, 22)];
    }

    NSTableColumn * scoreColumn = [tableView tableColumnWithIdentifier: @"score"];
    if ([LSLFuzzyAutocompleteSettings currentSettings].showScores) {
        if (!scoreColumn) {
            scoreColumn = [[NSTableColumn alloc] initWithIdentifier: @"score"];
            [tableView addTableColumn: scoreColumn];
            [tableView moveColumn: [tableView columnWithIdentifier: @"score"] toColumn: [tableView columnWithIdentifier: @"type"]];
            NSTextFieldCell * cell = [[tableView tableColumnWithIdentifier: @"title"].dataCell copy];
            NSNumberFormatter * formatter = [[NSNumberFormatter alloc] init];
            formatter.format = [LSLFuzzyAutocompleteSettings currentSettings].scoreFormat;
            cell.formatter = formatter;
            cell.title = @"";
            DVTFontAndColorTheme * theme = [DVTFontAndColorTheme currentTheme];
            cell.font = theme.sourcePlainTextFont;
            [scoreColumn setDataCell: cell];
        }
    } else if (scoreColumn) {
        [tableView removeTableColumn: scoreColumn];
    }
}

// We add a value for the new score column.
- (id) lslfa_tableView: (NSTableView *) aTableView
        valueForColumn: (NSTableColumn *) aTableColumn
                   row: (NSInteger) rowIndex
{
    if ([aTableColumn.identifier isEqualToString:@"score"]) {
        id<DVTTextCompletionItem> item = self.session.filteredCompletionsAlpha[rowIndex];
        return [self.session lslfa_scoreForItem: item];
    } else {
        return [self lslfa_tableView:aTableView valueForColumn:aTableColumn row:rowIndex];
    }
}

// We override this so we can mock tableView.rowHeight without affecting the display.
- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    NSNumber * obj = objc_getAssociatedObject(self, &kRowHeightKey);
    if (!obj) {
        obj = @(tableView.rowHeight);
        objc_setAssociatedObject(self, &kRowHeightKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        tableView.headerView.frame = NSMakeRect(0, 0, 100, tableView.rowHeight + tableView.intercellSpacing.height);

    }
    return [obj doubleValue];
}

// We modify the height to fit the header.
- (void) _lslfa_updateCurrentDisplayStateForQuickHelp {
    [self _lslfa_hackModifyRowHeight];
    [self _lslfa_updateCurrentDisplayStateForQuickHelp];
    [self _lslfa_hackRestoreRowHeight];
}

// We modify the width of the score column and height to accomodate the header.
- (void) _lslfa_updateCurrentDisplayState {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];

    // show or hide score column depending on wether we have scores
    NSTableColumn * scoreColumn = [tableView tableColumnWithIdentifier: @"score"];
    if (scoreColumn) {
        scoreColumn.minWidth = self.session.lslfa_nonZeroScores ? [self _lslfa_widthForScoreColumn] : -3;
        scoreColumn.maxWidth = scoreColumn.width = scoreColumn.minWidth;
    }

    // update the header text
    LSLTextCompletionListHeaderView * header = (LSLTextCompletionListHeaderView *) tableView.headerView;
    [header update: self.session];

    [self _lslfa_hackModifyRowHeight];
    [self _lslfa_updateCurrentDisplayState];
    [self _lslfa_hackRestoreRowHeight];

    // fix the tableView width when showing the window for the second time
    if ([LSLFuzzyAutocompleteSettings currentSettings].showScores) {
        [tableView sizeLastColumnToFit];
    }
}

// We add visual feedback for the matched ranges. Also format the score column.
- (void) _lslfa_tableView: (NSTableView *) aTableView
          willDisplayCell: (NSCell *) aCell
           forTableColumn: (NSTableColumn *) aTableColumn
                      row: (NSInteger) rowIndex
{
    [self _lslfa_tableView:aTableView willDisplayCell:aCell forTableColumn:aTableColumn row:rowIndex];

    if ([aTableColumn.identifier isEqualToString:@"score"]) {
        NSTextFieldCell * textFieldCell = (NSTextFieldCell *) aCell;
        textFieldCell.textColor = textFieldCell.isHighlighted ? [LSLFuzzyAutocompleteTheme cuurrentTheme].listTextColorForSelectedScore : [LSLFuzzyAutocompleteTheme cuurrentTheme].listTextColorForScore;
    } else if ([aTableColumn.identifier isEqualToString:@"title"]) {
        id<DVTTextCompletionItem> item = self.session.filteredCompletionsAlpha[rowIndex];
        NSArray * ranges = [self.session lslfa_matchedRangesForItem: item];

        if (!ranges.count) {
            return;
        }

        NSMutableAttributedString * attributed = [aCell.attributedStringValue mutableCopy];

        ranges = [self.session lslfa_convertRanges: ranges
                                        fromString: item.name
                                          toString: item.displayText
                                         addOffset: 0];

        NSDictionary * attributes = [LSLFuzzyAutocompleteTheme cuurrentTheme].listTextAttributesForMatchedRanges;

        for (NSValue * val in ranges) {
            [attributed addAttributes: attributes range: [val rangeValue]];
        }

        [aCell setAttributedStringValue: attributed];
    }

}

// we add to titleWidth to acomodate for additional column (last column is sized to fit).
- (void)_lslfa_getTitleColumnWidth:(double *)titleWidth typeColumnWidth:(double *)typeWidth {
    [self _lslfa_getTitleColumnWidth:titleWidth typeColumnWidth:typeWidth];
    if ([LSLFuzzyAutocompleteSettings currentSettings].showScores) {
        NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
        *titleWidth += [self _lslfa_widthForScoreColumn] + tableView.intercellSpacing.width;
    }
}

#pragma mark - helpers

// get width required for score column with current format and font
- (CGFloat) _lslfa_widthForScoreColumn {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
    NSTableColumn * scoreColumn = [tableView tableColumnWithIdentifier: @"score"];
    if (scoreColumn && self.session.lslfa_nonZeroScores) {
        NSNumberFormatter * formatter = ((NSCell *)scoreColumn.dataCell).formatter;
        NSString * sampleValue = [formatter stringFromNumber: @0];
        DVTFontAndColorTheme * theme = [DVTFontAndColorTheme currentTheme];
        NSDictionary * attributes = @{ NSFontAttributeName : theme.sourcePlainTextFont };
        return [[NSAttributedString alloc] initWithString: sampleValue attributes: attributes].size.width + 6;
    } else {
        return 0;
    }
}

// The _updateCurrentDisplayState and _updateCurrentDisplayStateForQuickHelp change tableView and window frame.
// If we just correct the dimensions after calling the originals, there sometimes is a visible jump in the UI.
// We therefore mock the row height to be larger, so the original methods size the tableView to be bigger.
// TODO: Do this in some cleaner way, maybe even without using a table view header.
- (void) _lslfa_hackModifyRowHeight {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
    LSLTextCompletionListHeaderView * header = (LSLTextCompletionListHeaderView *) tableView.headerView;
    NSInteger rows = MIN(8, [self.session.filteredCompletionsAlpha count]);
    double delta = header && rows ? (header.frame.size.height + 1) / rows : 0;

    tableView.rowHeight += delta;
}

// Restore the original row height.
- (void) _lslfa_hackRestoreRowHeight {
    NSTableView * tableView = [self valueForKey: @"_completionsTableView"];
    tableView.rowHeight = [objc_getAssociatedObject(self, &kRowHeightKey) doubleValue];
}

@end

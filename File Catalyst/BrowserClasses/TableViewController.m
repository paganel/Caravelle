//
//  TableViewController.m
//  Caravelle
//
//  Created by Nuno Brum on 03/04/15.
//  Copyright (c) 2015 Nuno Brum. All rights reserved.
//

#import "Definitions.h"
#import "TableViewController.h"
#import "CustomTableHeaderView.h"
#import "PasteboardUtils.h"
#import "NodeSortDescriptor.h"
#import "BrowserController.h"
#import "CalcFolderSizes.h"
#import "TreeViewer.h"


@interface TableViewController ( ) {
#ifdef UPDATE_TREE
    NSIndexSet *_draggedItemsIndexSet;
#endif
    NSMutableArray *observedTreeItemsForSizeCalculation;
    TreeViewer *_dataViewer;
}

-(TreeViewer*) currentViewer;

@end

@implementation TableViewController {
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.
    [self.myTableView setUsesAlternatingRowBackgroundColors:[[NSUserDefaults standardUserDefaults] boolForKey:USER_DEF_TABLE_ALTERNATE_ROW]];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:USER_DEF_TABLE_ALTERNATE_ROW options:NSKeyValueObservingOptionNew context:NULL];
    
}

-(void) setViewName:(NSString *)viewName {
    [super setViewName:viewName];
    //[[self myTableView] setAutosaveName:[self.viewName stringByAppendingString:@"Table"]];
    //[[self myTableView] setAutosaveTableColumns:YES];
}

- (void) initController {
    [super initController];
    observedTreeItemsForSizeCalculation = [[NSMutableArray alloc] init];
#ifdef UPDATE_TREE
    self->_draggedItemsIndexSet = nil;
#endif
    self->extendedSelection = nil;
    
    //To Get Notifications from the Table Header
#ifdef COLUMN_NOTIFICATION
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(selectColumnTitles:)
     name:notificationColumnSelect
     object:_myTableViewHeader];
#endif
}

- (NSView*) containerView {
    return self->_myTableView;
}


-(TreeViewer*) dataViewer {
    if (self->_dataViewer == nil) {
        self->_dataViewer = [[TreeViewer alloc] initWithParent:self.currentNode depth:0];
    }
    return self->_dataViewer;
}

-(NSObject <TreeViewerProtocol>*) currentViewer {
    return [self dataViewer];
}

/*
 -(id) getFileAtIndex:(NSUInteger)index {
 return [tableData objectAtIndex:index];
 }
*/

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
     if ([keyPath isEqualToString:USER_DEF_TABLE_ALTERNATE_ROW]) {
        [self.myTableView setUsesAlternatingRowBackgroundColors:[[NSUserDefaults standardUserDefaults] boolForKey:USER_DEF_TABLE_ALTERNATE_ROW]];
    }
    else
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark - TableView Datasource Protocol

/*
 * Table Data Source Protocol
 */
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [self.currentViewer count];
}

//- (NSTableRowView *)tableView:(NSTableView *)tableView rowViewForRow:(NSInteger)row {
//    NSTableRowView *rowView = [[NSTableRowView alloc] init];
//    id objectValue = [self->_displayedItems objectAtIndex:row];
//    return rowView;
//}


- (NSView *)tableView:(NSTableView *)aTableView viewForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    TreeItem *objectValue = [self.currentViewer itemAtIndex:rowIndex];
    // In IB the tableColumn has the identifier set to the same string as the keys in our dictionary
    
    
    NSDictionary *colControl = [columnInfo() objectForKey:[aTableColumn identifier]];
    NSString *identifier = [colControl objectForKey:COL_COL_ID_KEY];
    if (identifier==nil) {
        identifier = COL_TEXT_ONLY;
    }
    NSTableCellView *cellView = nil;

    TreeItem* theFile = objectValue;
    
    if ([self.currentViewer isGroup:rowIndex]) {
        // this is a group Row
        cellView = [aTableView makeViewWithIdentifier:ROW_GROUP owner:self];
        [cellView.textField setStringValue:self.currentViewer.groupTitle];
        [cellView setObjectValue:objectValue];
    }
    else {
        
        if ([identifier isEqualToString:COL_FILENAME]) {
            // We pass us as the owner so we can setup target/actions into this main controller object
            cellView = [aTableView makeViewWithIdentifier:COL_FILENAME owner:self];
            
            // If it's a new file, then assume a default ICON
            
            // Then setup properties on the cellView based on the column
            [cellView setToolTip:[theFile hint]]; //TODO:!!!! Add tool tips lazyly by using view: stringForToolTip: point: userData:
            
            cellView.imageView.objectValue = [theFile image];
            
            // Setting the color
            [cellView.textField setTextColor:[theFile textColor]];
        }
    
        else if ([identifier hasPrefix:COL_SIZE]) { // SIZES
            cellView = [aTableView makeViewWithIdentifier:COL_SIZE owner:self];
            [((SizeTableCellView*)cellView)  stopAnimation];
            
        }
        else
            // We pass us as the owner so we can setup target/actions into this main controller object
            cellView = [aTableView makeViewWithIdentifier:COL_TEXT_ONLY owner:self];
        
        if (colControl!=nil) { // The column exists
            NSString *prop_name = colControl[COL_ACCESSOR_KEY];
            id prop = nil;
            @try {
                prop = [objectValue valueForKey:prop_name];
            }
            @catch (NSException *exception) {
                NSLog(@"BrowserController.tableView:viewForTableColumn:row - Property '%@' not found", prop_name);
            }
            
            if (prop){
                if ([prop isKindOfClass:[NSString class]])
                    cellView.textField.objectValue = prop;
                else { // Need to use one of the NSValueTransformers
                    NSString *trans_name = [colControl objectForKey:COL_TRANS_KEY];
                    if (trans_name) {
                        NSValueTransformer *trans=[NSValueTransformer valueTransformerForName:trans_name];
                        if (trans) {
                            NSString *text = [trans transformedValue:prop];
                            if (text)
                                cellView.textField.objectValue = text;
                            else
                                cellView.textField.objectValue = @"error transforming value";
                        }
                        else
                            cellView.textField.objectValue = @"invalid transformer";
                    }
                    else
                        cellView.textField.objectValue = @"no transformer found";
                }
            }
            else {
                // If its the filesize and it wasn't found, ask for size computation
                if ([theFile needsSizeCalculation] && [identifier hasPrefix:@"COL_SIZE"] && [[NSUserDefaults standardUserDefaults] boolForKey:USER_DEF_CALCULATE_SIZES]) {
                    
                    [(TreeBranch*)theFile calculateSize]; // only if the calculation was started successfully
                    cellView.textField.objectValue = @"";
                    [((SizeTableCellView*)cellView)  startAnimation];
                    
                    // Adds to the the observed list
                    if ([self->observedTreeItemsForSizeCalculation containsObject:theFile]== NO) {
                        [theFile addObserver:self forKeyPath:kvoTreeBranchPropertySize options:0 context:nil];
                        [self->observedTreeItemsForSizeCalculation addObject:theFile];
                    }
                }
                else
                    cellView.textField.objectValue = @"--";
            }
        }
        else {
            cellView.textField.objectValue = @"Invalid Column";
        }
        
        

    }
    // All Columns will have the ObjectValue pointer defined.
    [cellView setObjectValue:objectValue];

    // other cases are not considered here. returning Nil
    return cellView;
}


#pragma mark - TableView View Delegate Protocol

/*
 * Table Data View Delegate Protocol
 */

// We want to make "group rows" for the folders
- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    BOOL answer =  [self.currentViewer isGroup:row];
    return answer;
}

// This function makes sure that the group headers are not selected
- (BOOL)tableView:(NSTableView *)aTableView
  shouldSelectRow:(NSInteger)rowIndex {
    id item = [self.currentViewer itemAtIndex:rowIndex];
    if ([self.currentViewer isGroup:rowIndex])
        return NO;
    else if ([item isKindOfClass:[TreeItem class]])
        return [item isSelectable];
    else
        return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    [self.parentController updateFocus:self];
    if([[aNotification name] isEqual:NSTableViewSelectionDidChangeNotification ]){
        [self.parentController selectionDidChangeOn:self]; // Will Trigger the notification to the status bar
    }
}

// -------------------------------------------------------------------------------
//	didClickTableColumn:tableColumn
// -------------------------------------------------------------------------------
- (void)tableView:(NSTableView *)inTableView didClickTableColumn:(NSTableColumn *)tableColumn
{
    // TODO:1.5 if Control or Alt is presssed the new column is just added to the sortDescriptor
    // NSUInteger modifierKeys = [NSEvent modifierFlags];
    // test NSControlKeyMask and NSAlternateKeyMask


    for (NSTableColumn *col in [inTableView tableColumns])
    {
        /* Will delete all indicators from the remaining columns */
        if (col!=tableColumn)
        {
            [inTableView setIndicatorImage:nil inTableColumn:col];
        }
    }
    [inTableView setHighlightedTableColumn:tableColumn];
    NodeSortDescriptor *currentDesc = [self.sortDescriptors sortDescriptorForFieldID:[tableColumn identifier]];

    BOOL ascending;
    if (currentDesc==nil || [currentDesc ascending]==NO)
    {
        [inTableView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
        ascending = YES;
    }
    else
    {
        [inTableView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
        ascending = NO;
    }
    [self makeSortOnFieldID:[tableColumn identifier] ascending:ascending];
    [self refreshKeepingSelections];
}

#pragma mark - Column Support

#ifdef COLUMN_NOTIFICATION

-(void) selectColumnTitles:(NSNotification *) note {
    // first checks the object sender is ours
    if ([note object]==_myTableViewHeader) {
        NSInteger colHeaderClicked = [[[note userInfo] objectForKey:kReferenceViewKey] integerValue];
        NSString *changedColumnID = [[note userInfo] objectForKey:kColumnChanged];

        // column select procedure
        if (changedColumnID!=nil) {
            // Get the needed informtion from the notification
            NSDictionary *colInfo = [columnInfo() objectForKey:changedColumnID];

            assert (colInfo); // Checking Problem in getting
            // Checks whether to add or to delete a column
            if ([[self myTableView] columnWithIdentifier:changedColumnID]==-1) { // column not existing
                // It was added
                NSTableColumn *columnToAdd= [NSTableColumn alloc];
                columnToAdd = [columnToAdd initWithIdentifier:changedColumnID];
                [[columnToAdd headerCell] setStringValue:colInfo[COL_TITLE_KEY]];
                [[self myTableView] addTableColumn:columnToAdd];
                NSInteger lastColumn = [[self myTableView] numberOfColumns] - 1 ;
                if (colHeaderClicked>=0 && colHeaderClicked<lastColumn-1) { // -1 so to avoid calling a move to the same position
                    [[self myTableView] moveColumn:lastColumn toColumn:colHeaderClicked+1]; // Inserts to the right
                }
            }
            else {
                // It was removed
                NSTableColumn *colToDelete = [[self myTableView] tableColumnWithIdentifier:changedColumnID];
                [[self myTableView] removeTableColumn:colToDelete];
            }
        }
        else {
            // Get the column
            NSTableColumn *colToGroup = [[[self myTableView] tableColumns] objectAtIndex:colHeaderClicked];
            // Remove it from Columns : [[self myTableView] removeTableColumn:colToGroup];
            [self makeGroupingOnFieldID:[colToGroup identifier] ascending:YES];
        }
        [self refreshKeepingSelections];
    }
}

#endif

-(void) setupColumns:(NSArray*) columns {

    // Removing all columns
    while ([self.myTableView.tableColumns count]) {
        NSTableColumn *col = self.myTableView.tableColumns[0];
        [self.myTableView removeTableColumn:col];
    }
    
    // Cancel all sorts
    [self.sortDescriptors removeAll];
    
    // Cycling throgh the columns to set
    for (NSString *colID in columns) {
        // Needs to insert this new column
        NSTableColumn *columnToAdd= [[NSTableColumn alloc] initWithIdentifier:colID];
        [[columnToAdd headerCell] setStringValue:columnInfo()[colID][COL_TITLE_KEY]];
        [[self myTableView] addTableColumn:columnToAdd];
    }
}

-(NSArray*) columns {
    // Gets the array with all the column identifiers
    NSArray *columns = [[self.myTableView tableColumns] valueForKeyPath:@"@unionOfObjects.identifier"];
    return columns;
}

-(void) loadPreferencesFrom:(NSDictionary*) preferences {
    [super loadPreferencesFrom:preferences];
    NSArray *columns = [preferences objectForKey:USER_DEF_TABLE_VIEW_COLUMNS];
    if (columns) {
        [self setupColumns:columns];
    }
    NSArray *widths = [preferences objectForKey:USER_DEF_TABLE_VIEW_COLUMNS_WIDTH];
    for (NSInteger i=0; i < [widths count]; i++) {
        NSTableColumn *column = [[[self myTableView] tableColumns] objectAtIndex:i];
        CGFloat width = [(NSNumber*)[widths objectAtIndex:i] floatValue];
        [column setWidth:width];
    }
    //[self.myTableView setUsesAlternatingRowBackgroundColors:[[NSUserDefaults standardUserDefaults] boolForKey:USER_DEF_TABLE_ALTERNATE_ROW]];
}

-(void) addColumn:(NSString*) fieldID {
    NSDictionary *colInfo = [columnInfo() objectForKey:fieldID];
    assert (colInfo); // Checking Problem in getting
    // Checks whether to add or to delete a column
    if ([[self myTableView] columnWithIdentifier:fieldID]==-1) { // column not existing
        // It was added
        NSTableColumn *columnToAdd= [NSTableColumn alloc];
        columnToAdd = [columnToAdd initWithIdentifier:fieldID];
        [[columnToAdd headerCell] setStringValue:colInfo[COL_TITLE_KEY]];
        [[self myTableView] addTableColumn:columnToAdd];
    }
    else {
        // It was removed
        [self removeColumn:fieldID];
    }

}

-(void) removeColumn:(NSString*) fieldID {
    NSTableColumn *colToDelete = [[self myTableView] tableColumnWithIdentifier:fieldID];
    [[self myTableView] removeTableColumn:colToDelete];
}

-(void) savePreferences:(NSMutableDictionary*) preferences {
    [super savePreferences:preferences];
    NSArray *colIDs = [self columns];
    if (colIDs) {
        [preferences setObject:colIDs forKey:USER_DEF_TABLE_VIEW_COLUMNS];
        NSArray *widths = [[self.myTableView tableColumns] valueForKeyPath:@"@unionOfObjects.width"];
        [preferences setObject:widths forKey:USER_DEF_TABLE_VIEW_COLUMNS_WIDTH];
    }
}

-(void) resizeColumn:(NSInteger)column width:(CGFloat)width {
    //NSLog(@"TableViewController.resizeColumn:%li width:%f ",column, width);
    NSTableColumn *col = [[self.myTableView tableColumns] objectAtIndex:column];
    CGFloat adjustWidth = width;
    
    if (width<0) {
        // Automatic width detection
        CGSize res = [self.myTableView bounds].size;
        //NSLog(@"Table Width : %f Column Width: %f",res.width, [col width]);
        adjustWidth = 5.0; // minimum width that will accepted
        NSTableCellView *view;
        for (NSInteger i = 0; i < [self.currentViewer count]; i++ ) {
            view = [self.myTableView viewAtColumn:column row:i makeIfNecessary:NO];
            CGFloat maxWidth = [[view textField] sizeThatFits:res].width;
            //NSLog(@"%@ %f",view.textField.stringValue, maxWidth);
            if (maxWidth > adjustWidth)
                adjustWidth = maxWidth;
        }
        if ([[col identifier] isEqualToString:COL_FILENAME]) {
            if (view) // uses the last view
                adjustWidth += [[view textField] frame].origin.x;
        }
    }
    //NSLog(@"Adjust Size %f", adjustWidth);
    [col setWidth:adjustWidth];
    [self.myTableView displayIfNeeded];
    
}


// This action is called from the BrowserTableView when the contextual menu for groupings is called.
-(IBAction)groupContextSelect:(id)sender {
    NSInteger tag = [(NSMenuItem *)sender tag];
    NSInteger row = [[self myTableView] rightClickedRow];
    TreeItem *group = [self.currentViewer itemAtIndex: row];
    if (tag == GROUP_SORT_ASCENDING || tag == GROUP_SORT_DESCENDING ) {
        NSLog(@"TODO: IMPLEMENT sort change on groupings");
        // TODO:!!!!! implement this correctly
        // Changing the ascending key. Since that property is read-only, a new descriptor needs to be initialized
        // Retrieving position of descriptor
        //NSInteger i = [self.sortAndGroupDescriptors indexOfObject:group.descriptor];
        // Creating a new Descriptor from the old one
        // NSSortDescriptor *oldDesc = group.descriptor;
        // NodeSortDescriptor *updateDesc = [[NodeSortDescriptor alloc] initWithKey:oldDesc.key ascending:(tag==GROUP_SORT_ASCENDING)];
        // Needs to be a Grouping Descriptor
        // [updateDesc copyGroupObject: oldDesc];
        // Updates the sort Array
        // [self.sortAndGroupDescriptors setObject:updateDesc atIndexedSubscript:i];
    }
    else if (tag == GROUP_SORT_REMOVE ) {
        // removes the descriptor
        [self removeGroupings];
    }
    else {
        NSAssert(NO, @"Invalid tag received from group contextual Menu");
    }
    [self refreshKeepingSelections];
}

/* This action is associated manually with the doubleClickTarget in Bindings */
- (IBAction)TableDoubleClickEvent:(id)sender {
    NSIndexSet *rowsSelected = [_myTableView selectedRowIndexes];
    NSArray *itemsSelected = [self itemsAtIndexes:rowsSelected];
    [self orderOperation:opOpenOperation onItems:itemsSelected];
}

// This selector is invoked when the file was renamed or a New File was created
- (IBAction)filenameDidChange:(id)sender {
    NSInteger row = [_myTableView rowForView:sender];
    NSInteger column = [_myTableView columnForView:sender];
    
    if (column != [self.myTableView columnWithIdentifier:COL_FILENAME]) {
        // This was not supposed to happen. Best to undo any changes.
        [self.myTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                    columnIndexes:[NSIndexSet indexSetWithIndex:column]];
        return;
    }
    if (row != -1) {
        TreeItem *item = [self.currentViewer itemAtIndex: row];
        NSString const *operation=nil;
        if ([item hasTags:tagTreeItemNew]) {
            operation = opNewFolder;
            NSArray *items = [NSArray arrayWithObject:item];
            // [self orderOperation:] selector can't be used because it misses the kDFORenameFileKey
            NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:
                                  items, kDFOFilesKey,
                                  operation, kDFOOperationKey,
                                  [sender stringValue], kDFORenameFileKey,
                                  self.currentNode, kDFODestinationKey,
                                  //self, kFromObjectKey,
                                  nil];
            [[NSNotificationCenter defaultCenter] postNotificationName:notificationDoFileOperation object:self userInfo:info];

        }
        else {
            // If the name did change. Do rename.
            if (![[sender stringValue] isEqualToString:[item name]]) {
                [item setName: [sender stringValue]];
            }
        }
    }
}

#pragma mark - Selection Support Functions

-(NSArray*) getSelectedItems {
    NSArray* answer = nil;
    NSIndexSet *rowsSelected = [_myTableView selectedRowIndexes];
    answer = [self itemsAtIndexes:rowsSelected];
    return answer;
}

// Can select the current Node
- (NSArray*)getSelectedItemsForContextualMenu1 {
    NSArray* answer = nil; // This will send the last answer when further requests are done

    // if the click was outside the items displayed
    if ([_myTableView clickedRow] == -1 ) {
        // it returns nothing
        answer = [NSArray arrayWithObject:self.currentNode]; // It will return the current node.
    }
    else {
        NSIndexSet *selectedIndexes = [_myTableView selectedRowIndexes];
        // If the clicked row was in the selectedIndexes, then we process all selectedIndexes. Otherwise, we process just the clickedRow
        if(![selectedIndexes containsIndex:[_myTableView clickedRow]]) {
            selectedIndexes = [NSIndexSet indexSetWithIndex:[_myTableView clickedRow]];
        }
        answer = [self itemsAtIndexes:selectedIndexes];
    }

    return answer;
}

// Doesn't select the current Node
-(NSArray*) getSelectedItemsForContextualMenu2 {
    NSArray* answer = nil; // This will send the last answer when further requests are done
    
    // if the click was in one of the items displayed
    if ([_myTableView clickedRow] != -1 ) {
        NSIndexSet *selectedIndexes = [_myTableView selectedRowIndexes];
        // If the clicked row was in the selectedIndexes, then we process all selectedIndexes. Otherwise, we process just the clickedRow
        if(![selectedIndexes containsIndex:[_myTableView clickedRow]]) {
            selectedIndexes = [NSIndexSet indexSetWithIndex:[_myTableView clickedRow]];
        }
        answer = [self itemsAtIndexes:selectedIndexes];
    }
    
    return answer;
}

-(TreeItem*) getLastClickedItem {
    NSInteger row = [_myTableView clickedRow];
    if (row >=0 && row < [self.currentViewer count]) {
        // Returns the current selected item
        return [self.currentViewer itemAtIndex: row];
    }
    else {
        // Returns the displayed folder
        return self.currentNode;

    }
}

-(id) objectValueAtRow:(NSInteger) row {
    NSTableRowView *view = [self.myTableView rowViewAtRow:row makeIfNecessary:NO];
    NSTableCellView *cv = [view viewAtColumn:0]; // All views shold have the objectValue set
    return [cv objectValue];
}

-(NSInteger) indexOfItem:(TreeItem*)item {
    NSInteger row;
    for (row = 0 ; row < [self.myTableView numberOfRows]; row++) {
        id obj = [self objectValueAtRow:row];
        if ([item isEqual:obj])
            return row;
    }
    return NSNotFound;
}

-(NSMutableArray <TreeItem*> *) itemsAtIndexes:(NSIndexSet*)indexes {
    NSMutableArray <TreeItem*> *answer = [NSMutableArray arrayWithCapacity:indexes.count];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        id repObject = [self objectValueAtRow:idx];
        if ([repObject isKindOfClass:[TreeItem class]]) {
            [answer addObject:repObject];
        }
        *stop = NO;
    }];
    return answer;
}

-(NSIndexSet*) indexesWithHashes:(NSArray*) hashes {
    NSMutableIndexSet *answer;
    answer = [[NSMutableIndexSet alloc] init];
    for (NSInteger row=0; row < self.myTableView.numberOfRows; row++) {
        id obj = [self objectValueAtRow:row];
        if ([obj respondsToSelector:@selector(hashObject)]) {
            id hash = [obj hashObject];
            if ([hashes containsObject:hash]) {
                [answer addIndex:row];
            }
        }
    }
    return answer;
}


-(NSArray*) getSelectedItemsHash {
    NSIndexSet *rowsSelected = [_myTableView selectedRowIndexes];
    if ([rowsSelected count]==0)
        return nil;
    else {
        // using collection operator to get the array of the URLs from the selected Items
        NSArray *selectedItems = [self itemsAtIndexes:rowsSelected];
        if (selectedItems!=nil && [selectedItems count]>0) {
            return [selectedItems valueForKeyPath:@"@unionOfObjects.hashObject"];
        }
        else {
            return nil;
        }
    }
}

-(void) setSelectionByHashes:(NSArray *)hashes {
    if (hashes!=nil && [hashes count]>0) {
        NSIndexSet *select = [self indexesWithHashes:hashes];
        [_myTableView selectRowIndexes:select byExtendingSelection:NO];
    }
}

-(void) startBusyAnimations {
    [super startBusyAnimations];
    [self.myProgressIndicator setHidden:NO];
    [self.myProgressIndicator startAnimation:self];

}
-(void) stopBusyAnimations {
    [super stopBusyAnimations];
    [self.myProgressIndicator setHidden:YES];
    [self.myProgressIndicator stopAnimation:self];
}

-(void) refresh {
    [self startBusyAnimationsDelayed];
    [self collectItems];
    [self stopBusyAnimations];
    [_myTableView reloadData];
}

-(void) refreshKeepingSelections {
    // TODO:1.5 Animate the updates (new files, deleted files)
    // Storing Selected URLs
    NSArray *selectedHashes = [self getSelectedItemsHash];
    // Refreshing the View
    [self refresh];
    // Reselect stored selections
    [self setSelectionByHashes: selectedHashes];
}


-(void) reloadItem:(id) object {
    if (object == self.currentNode) {
        [self refresh];
    }
    else { // if its not the node, then it could be a table element
        NSInteger rowToReload = [self indexOfItem:object];
        if (rowToReload >=0  && rowToReload!=NSNotFound) {
            NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndex:rowToReload];
            NSRange columnsRange = {0, [[_myTableView tableColumns] count] };
            NSIndexSet *columnIndexes = [NSIndexSet indexSetWithIndexesInRange:columnsRange];
            [_myTableView reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];
        }
    }
}

-(void) reloadSize:(id) object {
    NSInteger rowToReload = [self indexOfItem:object];
    if (rowToReload >=0  && rowToReload!=NSNotFound) {
        NSIndexSet *rowIndexes = [NSIndexSet indexSetWithIndex:rowToReload];
        
        NSMutableIndexSet *columnIndexes = [[NSMutableIndexSet alloc] init];
        int index=0;
        for (NSTableColumn * colID in [self.myTableView tableColumns]) {
            if ([[colID identifier] hasPrefix:@"COL_SIZE"]) {
                [columnIndexes addIndex:index];
            }
            index++;
        }
        [_myTableView reloadDataForRowIndexes:rowIndexes columnIndexes:columnIndexes];

        // Now the observe can be removed
        if ([self->observedTreeItemsForSizeCalculation containsObject:object]) {
            [object removeObserver:self forKeyPath:kvoTreeBranchPropertySize];
            [self->observedTreeItemsForSizeCalculation removeObject:object];
        }
    }
}

- (void) reloadAll {
    [self.currentViewer setNeedsRefresh];
    [self.myTableView reloadData];
}

- (void) setCurrentNode:(TreeBranch*)branch {
    //Unobserve Tree Items that were set for size calculation
    for (TreeItem* item in self->observedTreeItemsForSizeCalculation) {
        [item removeObserver:self forKeyPath:kvoTreeBranchPropertySize];
    }
    if ([self->observedTreeItemsForSizeCalculation count]!=0) {
        // Cancelling all pending
        //NSLog(@"Canceling all size operations");
        NSArray *operations = [lowPriorityQueue operations];
        for (NSOperation *op in operations) {
            if ([op isKindOfClass:[CalcFolderSizes class]]) {
                NSLog(@"DEBUG setCurrentNode");
                TreeBranch *tb = [(CalcFolderSizes*)op item];
                if ([tb relationTo:branch] == pathIsParent) {
                    [op cancel];
                    [tb sizeCalculationCancelled];
                }
                
            }
        }
    }
    [self->observedTreeItemsForSizeCalculation removeAllObjects];
    
    [super setCurrentNode:branch];
    [self.myTableView reloadData];
}

#pragma mark - Drag and Drop Support


#ifdef USE_TREEITEM_PASTEBOARD_WRITING
- (id < NSPasteboardWriting >)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    return (id <NSPasteboardWriting>) [self.currentViewer itemAtIndex: row];
}

#else

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
    return writeItemsToPasteBoard(items, pboard, supportedPasteboardTypes());
}
#endif


- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
#ifdef UPDATE_TREE
    _draggedItemsIndexSet = rowIndexes; // Save the Indexes for later deleting or moving
#endif
}


- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {

#ifdef UPDATE_TREE
    // This is not needed if the FSEvents is activated and updates the Tables
    NSPasteboard *pboard = [session draggingPasteboard];
    //NSLog(@"ended dragging section");
    //DebugPBoard(pboard);
    NSArray *files = [pboard readObjectsForClasses:[NSArray arrayWithObjects:[NSURL class], nil] options:nil];
    if (operation == (NSDragOperationMove)) {
        [tableView removeRowsAtIndexes:_draggedItemsIndexSet withAnimation:NSTableViewAnimationEffectFade];
    }
    else if (operation ==  NSDragOperationDelete) {
        // Send to RecycleBin.
        [tableView removeRowsAtIndexes:_draggedItemsIndexSet withAnimation:NSTableViewAnimationEffectFade];
        sendItemsToRecycleBin(files);
    }
#endif
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
    self->_validatedDropDestination = nil;
    if (operation == NSTableViewDropAbove) { // This is on the folder being displayed
        self->_validatedDropDestination = self.currentNode;
    }
    else if (operation == NSTableViewDropOn) {

        @try { // If the row is not valid, it will assume the tree node being displayed.
            self->_validatedDropDestination = [self.currentViewer itemAtIndex: row];
        }
        @catch (NSException *exception) {
            self->_validatedDropDestination = self.currentNode;
        }
        @finally {
            // Go away... nothing to see here
        }
    }

    /* Limit the Operations depending on the Destination Item Class*/
    if ([self->_validatedDropDestination isFolder]) {
        // TODO:1.4 Put here a timer for opening the Folder
        // Recording time and first time
        // if not first time and recorded time > 3 seconds => open folder
    }
    NSDragOperation dragOperations =[self->_validatedDropDestination supportedPasteOperations:info];
    self->_validatedDropOperation = selectDropOperation(dragOperations);
    
    return self->_validatedDropOperation;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {

    
    NSArray* droppedFiles = [self->_validatedDropDestination acceptDropped:info operation:self->_validatedDropOperation sender:self];

    if (self->_validatedDropDestination == self.currentNode && droppedFiles!=nil) {
        //Inserts the rows using the specified animation.
        
        // TODO:1.4 Implement the insertion of TreeItems, Must change implementation of acceptDropped of TreeBranches.
        /*
        if (self->_validatedDropOperation & (NSDragOperationCopy | NSDragOperationMove)) {
            
            int i= 0;
            for (TreeItem* pastedItem in droppedFiles) {
                [pastedItem setTag:tagTreeItemDropped];
                [self->_displayedItems insertObject:pastedItem atIndex:row+i];
                [aTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row+i] withAnimation:NSTableViewAnimationSlideDown]; //TODO:? Try NSTableViewAnimationEffectGap
                i++;
            }
        }
         */
    }
    return droppedFiles!=nil;
}

// This selector is implemented in the super class
//-(void) menuNeedsUpdate:(NSMenu*) menu {
//    [super menu:menu updateItem:item atIndex:index shouldCancel:shouldCancel];
//}

#pragma mark - NSControlTextDelegate Protocol

- (void)keyDown:(NSEvent *)theEvent {
    // Get the origin
    NSString *key = [theEvent characters];
    unichar keyCode = [key characterAtIndex:0];
    NSString *keyWM = [theEvent charactersIgnoringModifiers];
    //NSLog(@"KD: code:%@ - %@, [%d,%d]",key, keyWM, keyCode, [keyWM characterAtIndex:0]);
    NSInteger behave = [[NSUserDefaults standardUserDefaults] integerForKey: USER_DEF_APP_BEHAVIOUR] ;

    if ([theEvent modifierFlags] & NSCommandKeyMask) {
        if (keyCode == KeyCodeDown) {    // will open the subject
            [self TableDoubleClickEvent:theEvent];
        }
        else if (keyCode == KeyCodeUp) {  // the CMD Up will up one directory level
            [[self parentController] upOneLevel];
        }
    }
    else if (([key isEqualToString:@"\r"] && behave == APP_BEHAVIOUR_MULTIPLATFORM) ||
        ([key isEqualToString:@" "] && behave == APP_BEHAVIOUR_NATIVE))
    {
        // The Return key will open the file
        [self TableDoubleClickEvent:theEvent];
    }
    else if ([key isEqualToString:@"\r"] && behave == APP_BEHAVIOUR_NATIVE) {
        // The return Key Edits the Name
        NSArray *itemsSelected = [self getSelectedItems];
        if (itemsSelected != nil) {
            // TODO:1.4 implement here the option for rename in window
            if ([itemsSelected count] == 1) {
                // if only one object selected
                [self startEditItemName:[itemsSelected firstObject]];
            }
            else {
                // Multiple rename
                //[NSApp performSelector:@selector(executeRename:) withObject:itemsSelected];
                // TODO:1.4 implement in future versions
                // For now just displaying an alert
                NSAlert *alert = [NSAlert alertWithMessageText:@"Multiple files selected!"
                                                 defaultButton:@"OK"
                                               alternateButton:nil
                                                   otherButton:nil
                                     informativeTextWithFormat:@"Multi-Rename of files will be enabled in a future version."];
                [alert setAlertStyle:NSWarningAlertStyle];
                [alert beginSheetModalForWindow:self.view.window completionHandler:NULL];
            }
        }
    }
    else if ([keyWM isEqualToString:@"\t"]) { // the tab key will switch Panes
        [[self parentController] focusOnNextView:self];
    }
    else if ([key isEqualToString:@"\x19"]) { // the Shift tab key will switch Panes
        [[self parentController] focusOnPreviousView:self];
    }
    else if ([key isEqualToString:@" "] && behave == APP_BEHAVIOUR_MULTIPLATFORM ) {
        // the Space Key will mark the file
        // only works the TableView
            if (self->extendedSelection==nil) {
                self->extendedSelection = [NSMutableIndexSet indexSet];
            }
            NSIndexSet *indexset = [_myTableView selectedRowIndexes];
            [indexset enumerateIndexesUsingBlock:^(NSUInteger index, BOOL * stop) {
                TreeItem* item = [self.currentViewer itemAtIndex: index];
                if (![item isGroup]) {
                    [item toggleTag:tagTreeItemMarked];
                }
                if ([self->extendedSelection containsIndex:index])
                    [self->extendedSelection removeIndex:index];
                else
                    [self->extendedSelection addIndex:index];
            }];

            // Check what is the preferred method
#ifdef REFRESH_ONLY_FILENAME
            // Only update the FileName Column
            NSIndexSet *colIndex = [NSIndexSet indexSetWithIndex:
                                    [self->_myTableView columnWithIdentifier:COL_FILENAME]];
#else
            NSRange columns = {0, [self->_myTableView numberOfColumns]};
            NSIndexSet *colIndex = [NSIndexSet indexSetWithIndexesInRange:columns];
#endif
            [self->_myTableView reloadDataForRowIndexes:indexset
                                          columnIndexes: colIndex];

    }
    else {
        [super keyDown:theEvent]; // Just passing it to the super class
    }
}


- (BOOL)control:(NSControl *)control textShouldBeginEditing:(NSText *)fieldEditor {
    NSInteger row = [_myTableView rowForView:fieldEditor];
    if (row!=-1) {
        id item = [self.currentViewer itemAtIndex: row];

        // In order to allow the creation of new files
        if ([item hasTags:tagTreeItemNew])
            return YES;
        return [item hasTags:tagTreeItemReadOnly]==NO;
    }
    else
        return YES;
}

// NSControlTextEditingDelegate
- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor doCommandBySelector:(SEL)commandSelector
{
    //NSLog(@"Selector method is (%@)", NSStringFromSelector( commandSelector ) );
    if (commandSelector == @selector(cancelOperation:)) {
        
        // In cancel will check if it was a new File and if so, remove it
        NSInteger row =[_myTableView rowForView:fieldEditor];
        if (row!=-1) {
            id item = [self.currentViewer itemAtIndex: row];
            if ([item isKindOfClass:[TreeItem class]]) {
                if ([(TreeItem*)item hasTags:tagTreeItemNew]) {
                    NSIndexSet *rows2delete = [NSIndexSet indexSetWithIndex:row];
                    [_myTableView removeRowsAtIndexes:rows2delete
                                        withAnimation:NSTableViewAnimationEffectFade];
                }
                else {
                    // Reposition the old text
                    [control setStringValue:[item name]];
                }
            }
        }
        //[fieldEditor resignFirstResponder];
        //[self focusOnLastView];
        //return YES;  // avoids that the cancelOperation from controller is called.
    }

    return NO;
}



-(BOOL) startEditItemName:(TreeItem*)item  {
    NSUInteger row = [self indexOfItem: item];
    if (row!=NSNotFound) {
        NSInteger column = [_myTableView columnWithIdentifier:COL_FILENAME];
        if (column != -1 ) {
            [_myTableView editColumn:column row:row withEvent:nil select:YES];
            // Obtain the NSTextField from the view
            NSTextField *textField = [[_myTableView viewAtColumn:column row:row makeIfNecessary:NO] textField];
            assert(textField!=nil);
            // Recuperate the old filename
            NSString *oldFilename = [textField stringValue];
            // Select the part up to the extension
            NSUInteger head_size = [[oldFilename stringByDeletingPathExtension] length];
            NSRange selectRange = {0, head_size};
            [[textField currentEditor] setSelectedRange:selectRange];
            return YES;
        }
    }
    return NO;
}

-(void) insertItem:(id)item  {
    NSInteger row;
    NSIndexSet *selection = [_myTableView selectedRowIndexes];
    if ([selection count]>0) {
        // Will insert a row on the bottom of the selection.
        row = [selection lastIndex] + 1;
    }
    else {
        row = [self.currentViewer count];
    }
    assert(NO); // TODO:!!!!! Need to implement this : Add the new item to the data source
    [_myTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row] withAnimation: NSTableViewAnimationEffectNone]; //NSTableViewAnimationSlideDown, NSTableViewAnimationEffectGap

    // Making the new inserted line as selected
    [_myTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
}

// First Selectable row
-(NSInteger) firstSelectableRow {
    NSInteger row=0;
    while (row < [self.currentViewer count]) {
        if ([[self.currentViewer itemAtIndex: row] isGroup]==NO)
            return row;
        row++;
    }
    return -1;
}

-(void) focusOnFirstView {
    if ([[_myTableView selectedRowIndexes] count]==0) {
        NSInteger first = [self firstSelectableRow];
        if (first != -1) {
            [_myTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:first] byExtendingSelection:NO];
        }
    }
    [self.myTableView.window makeFirstResponder:self.myTableView];

}
-(void) focusOnLastView {
    if ([[_myTableView selectedRowIndexes] count]==0) {
        NSInteger first = [self firstSelectableRow];
        if (first != -1) {
            [_myTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:first] byExtendingSelection:NO];
        }
    }
    [self.myTableView.window makeFirstResponder:self.myTableView];
}

@end

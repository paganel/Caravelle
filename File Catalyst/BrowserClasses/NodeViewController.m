//
//  NodeViewController.m
//  Caravelle
//
//  Created by Nuno Brum on 04/04/15.
//  Copyright (c) 2015 Nuno Brum. All rights reserved.
//

#import "NodeViewController.h"
#import "PasteboardUtils.h"
#import "CustomTableHeaderView.h"
#import "DummyBranch.h"
#import "CatalogBranch.h"
#import "myValueTransformers.h"
#import "TreeEnumerator.h"

EnumContextualMenuItemTags viewMenuFiles[] = {
    menuInformation,
    menuView,
    menuOpen,
    menuOpenWith,
    menuRename,
    menuDelete,
    menuDivider,
    menuAddFavorite,
    menuDivider,
    menuClipCut,
    menuClipCopy,
    menuClipPaste,
    menuDivider,
    menuEnd
};

EnumContextualMenuItemTags viewMenuNoFiles[] = {
    menuAddFavorite,
    menuNewFolder,
    menuInformation,
    menuDivider,
    menuClipPaste,
    menuDivider,
    menuEnd,
};

EnumContextualMenuItemTags viewMenuLeft[] = {
    menuCopyRight,
    menuMoveRight,
    menuDivider,
    menuEnd
};

EnumContextualMenuItemTags viewMenuRight[] = {
    menuCopyLeft,
    menuMoveLeft,
    menuDivider,
    menuEnd
};

#define SECTION_BUFFER_INCREASE 20

@interface NodeViewController () {
    TreeBranch *_currentNode;
    NSMutableArray *_observedVisibleItems;
}

@end

@implementation NodeViewController {
    BOOL animation_needed;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do view setup here.

}

// -------------------------------------------------------------------------------
//	awakeFromNib
// -------------------------------------------------------------------------------
- (void)awakeFromNib
{
    
}

-(void) setName:(NSString*)viewName twinName:(NSString*)twinName {
    [self setViewName:viewName];
    self->_twinName = twinName;
}

- (NSString*)twinName {
    return _twinName;
}

- (void) initController {
    self->_extendToSubdirectories = NO;
    self->_foldersInTable = YES;
    self->_currentNode = nil;
    self->_observedVisibleItems = [[NSMutableArray new] init];
    self.sortAndGroupDescriptors = nil;
    [self startBusyAnimations];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:USER_DEF_DISPLAY_FOLDERS_FIRST
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];
    
    [[NSUserDefaults standardUserDefaults] addObserver:self
                                            forKeyPath:USER_DEF_DISPLAY_PARENT_DIRECTORY
                                               options:NSKeyValueObservingOptionNew
                                               context:NULL];
    
}

- (void)dealloc {
    //  Stop any observations that we may have
    [self unobserveAll];
    //    [super dealloc];
}

-(void) updateFocus:(id)sender {
    [[self parentController] updateFocus:self];
}

-(void) contextualFocus:(id)sender {
    [[self parentController] contextualFocus:self];
}

- (NSView*) containerView {
    NSAssert(NO,@"Assert Error. This is a virtual method");
    return nil;
}

- (void) setCurrentNode:(TreeBranch*)branch {
    [self unobserveItem:self.currentNode];

    self->_currentNode = branch;
    if (branch!=nil) {
        [self observeItem:self.currentNode];
        [branch refresh];
    }
}

- (TreeBranch*) currentNode {
    return self->_currentNode;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if ([keyPath isEqualToString:kvoTreeBranchPropertyChildren]) {
        // Find the row and reload it.
        // Note that KVO notifications may be sent from a background thread (in this case, we know they will be)
        // We should only update the UI on the main thread, and in addition, we use NSRunLoopCommonModes to make sure the UI updates when a modal window is up.
        [self performSelectorOnMainThread:@selector(reloadItem:) withObject:object waitUntilDone:NO modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    }
    else if ([keyPath isEqualToString:kvoTreeBranchPropertySize]) {
        [self performSelectorOnMainThread:@selector(reloadSize:) withObject:object waitUntilDone:NO modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
    }
    else if ([keyPath isEqualToString:USER_DEF_DISPLAY_FOLDERS_FIRST] ||
             [keyPath isEqualToString:USER_DEF_DISPLAY_PARENT_DIRECTORY]) {
        //NSLog(@"NodeViewController.observeValueForKeyPath: %@", keyPath);
        [self refreshKeepingSelections];
    }
}

-(void) observeItem:(TreeItem*)item {
    // Use KVO to observe for changes of its children Array
    if (item !=nil && ![_observedVisibleItems containsObject:item]) {
        [item addObserver:self forKeyPath:kvoTreeBranchPropertyChildren options:0 context:NULL];
        [_observedVisibleItems addObject:item];
    }
}

-(void) unobserveItem:(TreeItem*)item {
    // Use KVO to observe for changes of its children Array
    if (item!=nil && [_observedVisibleItems containsObject:item]) {
        [item removeObserver:self forKeyPath:kvoTreeBranchPropertyChildren];
        [_observedVisibleItems removeObject:item];
    }
}

-(void) unobserveAll {
    for (TreeBranch* item in _observedVisibleItems) {
        [item removeObserver:self forKeyPath:kvoTreeBranchPropertyChildren];
    }
    [_observedVisibleItems removeAllObjects];
}

#pragma mark - Menu Support 

// Make a Full programatic menu
-(void) menuNeedsUpdate:(NSMenu*) menu {
    //NSLog(@"NodeViewController.menuNeedsUpdate");
    // tries a contextual excluding the click in blank space
    [menu removeAllItems];
    NSArray *itemsSelected = [self getSelectedItemsForContextualMenu2];
    if (itemsSelected==nil) {
        itemsSelected = [self getSelectedItemsForContextualMenu1];
        updateContextualMenu(menu, itemsSelected, viewMenuNoFiles);
    }
    else {
        updateContextualMenu(menu, itemsSelected, viewMenuFiles);
        if (self.twinName!=nil) {
            if ([[self viewName] isEqualToString:@"Left"]) {
                updateContextualMenu(menu, itemsSelected, viewMenuLeft);
            }
            else {
                updateContextualMenu(menu, itemsSelected, viewMenuRight);
            }
        }
    }
}

-(void) reloadItem:(id)object {
    NSAssert(NO, @"NodeViewController.reloadItem: This method needs to be overriden");
}

-(void) reloadSize:(id)object {
    NSAssert(NO, @"NodeViewController.reloadSize: This method needs to be overriden");
}

-(BOOL) startEditItemName:(TreeItem*)item {
    NSLog(@"NodeViewController.startEditItemName: This method needs to be overriden");
    return NO;
}

-(void) insertItem:(id)item {
    NSAssert(NO, @"NodeViewController.insertItem: This method should be overriden");
}


// TODO:!!!!!!! Move this to a C callable function
- (void) orderOperation:(NSString const*)operation onItems:(NSArray*)orderedItems;
 {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              orderedItems, kDFOFilesKey,
                              operation, kDFOOperationKey,
                              self.currentNode, kDFODestinationKey,
                              self, kDFOFromViewKey,
                              nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:notificationDoFileOperation object:self userInfo:userInfo];
}

- (void) refresh {
    NSAssert(NO, @"NodeViewController.refresh: This method needs to be overriden");
}

-(void) refreshKeepingSelections {
    NSAssert(NO, @"NodeViewController.refreshKeepingSelections: This method needs to be overriden");
}

- (void) registerDraggedTypes {
    [[(id<NodeViewProtocol>)self containerView] registerForDraggedTypes: supportedPasteboardTypes()];

}

- (void) unregisterDraggedTypes {
    [[(id<NodeViewProtocol>)self containerView] unregisterDraggedTypes];

}

/* The menu handling is forwarded to the Delegate.
 For the contextual Menus the selection is different, than for the application */
- (id)validRequestorForSendType:(NSString *)sendType
                     returnType:(NSString *)returnType
{
    return [(id<MYViewProtocol>)[self parentController] validRequestorForSendType:sendType returnType:returnType];
}

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
                             types:(NSArray *)types
{
    NSArray *selectedFiles = [self getSelectedItemsForContextualMenu2];
    return writeItemsToPasteboard(selectedFiles, pboard, types);

}

- (void)cancelOperation:(id)sender {
    // clean the filter
    [[self parentController] performSelector:@selector(cancelOperation:) withObject:self];
    // and pass the cancel operation upwards anyway
}

- (void) focusOnFirstView {
    //NSLog(@"NodeViewController.focusOnFirstView: should be overriden");
    [self.view.window makeFirstResponder:self.containerView];
}

- (void) focusOnLastView {
    //NSLog(@"NodeViewController.focusOnLastView: should be overriden");
    [self.view.window makeFirstResponder:self.containerView];
}

- (NSView*) focusedView {
    //NSLog(@"NodeViewController.focusedView: should be overriden");
    static NSView *lastFocus=nil;
    id control = [[[self containerView] window] firstResponder];
    if ([control isKindOfClass:[NSView class]]) {
        lastFocus = control;
    }
    return lastFocus;
}

-(NSInteger) insertGroups:(NSMutableArray*)items start:(NSUInteger)start stop:(NSUInteger)stop descriptorIndex:(NSUInteger)descIndex {
    // Verify in no more descriptors to process
    NSInteger inserted = 0;
    if (descIndex < [self.sortAndGroupDescriptors count]) {
        NodeSortDescriptor *sortDesc = [self.sortAndGroupDescriptors objectAtIndex:descIndex];

        if (sortDesc.isGrouping) { // Grouping is needed for this descriptor
            NSUInteger i = start;
            NSArray *groups = nil;
            while (i < (stop+inserted)) {
                groups = [sortDesc groupItemsForObject: items[i]];
                if (groups!=nil) {
                    for (GroupItem *GI in groups) {
                        [items insertObject:GI atIndex:i - GI.nElements];
                        i++;
                        //NSInteger nInserted = [self insertGroups:items start:i - GI.nElements stop:i descriptorIndex:descIndex+1];
                        //NSLog(@"Inserted %@ at %ld, nElements %ld", GI.title, i - GI.nElements - nInserted, GI.nElements);
                        inserted += 1; // + nInserted;
                        //i += nInserted;
                    }
                }
                i++;
            }
            groups = [sortDesc flushGroups];
            if (groups!=nil) {
                i--; // Needs to be in the last position
                for (GroupItem *GI in groups) {
                    [items insertObject:GI atIndex:i - GI.nElements];
                    i++;
                    //NSInteger nInserted = [self insertGroups:items start:i - GI.nElements stop:i descriptorIndex:descIndex+1];
                    inserted += 1 ;// + nInserted;
                    //i += nInserted;
                }
            }
        }
    }
    return inserted;
}

-(IBAction) menuGroupingSelector:(id) sender {
    //NSLog(@"NodeViewController.menuGroupingSelector %@",[sender title]);
    BOOL activate_grouping = toggleMenuState((NSMenuItem *)sender);

    // Find the identifier
    NSDictionary *colDict = nil;
    NSString *identifier;
    for (NSString *ident in [columnInfo() keyEnumerator]) {
        colDict = [columnInfo() objectForKey:ident];
        if ([[sender title] isEqualToString:colDict[COL_TITLE_KEY]]) {
            identifier = ident;
            break;
        }
    }
    BOOL ascending = NO; // Just initialize with something
    if (activate_grouping) {
        NodeSortDescriptor *currentDesc = [self sortDescriptorForFieldID: identifier];
        if (currentDesc==nil || [currentDesc ascending]==NO)
        {
            ascending = YES;
        }
        else
        {
            ascending = NO;
        }
    }
    [self makeSortOnFieldID:identifier ascending:ascending grouping:activate_grouping];
    [self refreshKeepingSelections];
}

-(IBAction) menuColumnSelector:(id) sender {
    // Find the identifier
    NSDictionary *colDict = nil;
    NSString *identifier;
    for (NSString *ident in [columnInfo() keyEnumerator]) {
        colDict = [columnInfo() objectForKey:ident];
        if ([[sender title] isEqualToString:colDict[COL_TITLE_KEY]]) {
            identifier = ident;
            break;
        }
    }
    [self addColumn:identifier]; // This function is already removing if it already exists
}

-(void) collectItems_old {
    NSMutableArray *tableData = nil;
    /* Always uses the self.currentNode property to manage the Table View */
    // Get the depth configuration
    NSInteger iDepth = NSIntegerMax;
    //NSLog(@"NodeViewController.itemsToDisplay view:%@ URL:%@",self->_viewName, self.currentNode.url);

    if ([self.currentNode isFolder]){
        /* if the filter is empty, doesn't filter anything */
        if (_filterText!=nil && [_filterText length]!=0) {
            NSPredicate *predicate;
            NSCharacterSet *specialCharacters = [NSCharacterSet characterSetWithCharactersInString:@"=~|&<>"];
            if ([self.filterText rangeOfCharacterFromSet:specialCharacters].location!=NSNotFound) {
                // TODO:1.5 Tokenize the filter field to make inteligent searches
                // TODO:1.5 find Titles and replace for selectors.
                @try {
                    predicate = [NSPredicate predicateWithFormat:self.filterText];
                }
                @catch (NSException *exception) {
                    predicate = nil;
                }
                /*@finally {}*/
            }
            else {
                
                NSString *attributeName  = @"name";
                NSCharacterSet *wildcards = [NSCharacterSet characterSetWithCharactersInString:@"?*"];
                NSRange wildcardsPresent = [self.filterText rangeOfCharacterFromSet:wildcards];
                
                if (wildcardsPresent.location == NSNotFound)  // Wildcard not presents
                    predicate   = [NSPredicate predicateWithFormat:@"%K contains[cd] %@",
                                   attributeName, self.filterText];
                else
                    predicate   = [NSPredicate predicateWithFormat:@"%K like[cd] %@",
                                   attributeName, self.filterText];
            }
            
            if (self.filesInSubdirsDisplayed==YES) {
                tableData = [self.currentNode leafsInBranchWithPredicate:predicate depth:iDepth];
            }
            else if (self.filesInSubdirsDisplayed==NO && self.foldersInTable==YES) {
                tableData = [self.currentNode itemsInNodeWithPredicate:predicate];
            }
            else if (self.filesInSubdirsDisplayed==NO && self.foldersInTable==NO) {
                tableData = [self.currentNode leafsInNodeWithPredicate:predicate];
            }
            
        }
        else {
            if (self.filesInSubdirsDisplayed==YES) {
                tableData = [self.currentNode leafsInBranchTillDepth:iDepth];
            }
            else if (self.filesInSubdirsDisplayed==NO && self.foldersInTable==YES) {
                tableData = [self.currentNode itemsInNode];
            }
            else if (self.filesInSubdirsDisplayed==NO && self.foldersInTable==NO) {
                tableData = [self.currentNode leafsInNode];
            }
        }
        
        if (self.foldersInTable==YES) {
            // Adding the Folders First Sort
            // TODO: This is silly to be done all the time, but at leat it assures that its not
            // overriden by other sorts. Find another way to do this
            if ([[NSUserDefaults standardUserDefaults] boolForKey:USER_DEF_DISPLAY_FOLDERS_FIRST]) {
                [self makeSortOnFieldID:SORT_FOLDERS_FIRST_FIELD_ID ascending:YES grouping:NO];
            }
            else
                [self removeSortOnField:SORT_FOLDERS_FIRST_FIELD_ID];
        }
        
        // Sort Data
        if ((self.sortAndGroupDescriptors!=nil) && ([self.sortAndGroupDescriptors count] > 0)) {
            NSArray *sortedArray = [tableData sortedArrayUsingDescriptors:self.sortAndGroupDescriptors];
            tableData = [NSMutableArray arrayWithArray:sortedArray];

            // Insert Groupings if needed
            if ([(NodeSortDescriptor*)[self.sortAndGroupDescriptors firstObject] isGrouping]) {
                // Since the sort groupings are always the first elements on the table
                // it sufices to test the first element to know if a grouping is needed

                // Need to restart all the descriptors
                for (NodeSortDescriptor *sortDesc in self.sortAndGroupDescriptors) {
                    if ([sortDesc isGrouping])
                        [sortDesc reset];
                    else
                        break;
                }
                [self insertGroups:tableData start:0 stop:[tableData count] descriptorIndex:0];
            }
        }
        
        // Adding the parent directory as .. if requested
        if ([[NSUserDefaults standardUserDefaults] boolForKey:USER_DEF_DISPLAY_PARENT_DIRECTORY] &&
            self.foldersInTable==YES) {
            DummyBranch *dummyParent = [DummyBranch parentFor:self.currentNode]; 
            if (dummyParent != nil) {
                [dummyParent setTag:tagTreeItemReadOnly];
                [tableData insertObject:dummyParent atIndex:0];
            }
        }
    }
    //self->_displayedItems = tableData;
}

-(void) collectItems {
    
    // Get the depth configuration
    
    if ([self.currentNode isFolder]){
        
        if (_depth <= 10) {
            if (self.foldersInTable==YES) {
                _treeViewer = [[TreeViewer alloc] initWithID:self.viewName viewing:self.currentNode depth: _depth];
            }
            else {//if (self.foldersInTable==NO) {
                //NSAssert(NO, @"Implemetation Missing");
                _treeViewer = [[TreeViewer alloc] initWithID:self.viewName viewing:self.currentNode depth: _depth];
            }
            if (_filterText!=nil && [_filterText length]!=0) {
                NSPredicate *predicate;
                NSCharacterSet *specialCharacters = [NSCharacterSet characterSetWithCharactersInString:@"=~|&<>"];
                if ([self.filterText rangeOfCharacterFromSet:specialCharacters].location!=NSNotFound) {
                    // TODO:1.5 Tokenize the filter field to make inteligent searches
                    // TODO:1.5 find Titles and replace for selectors.
                    @try {
                        predicate = [NSPredicate predicateWithFormat:self.filterText];
                    }
                    @catch (NSException *exception) {
                        predicate = nil;
                    }
                    /*@finally {}*/
                }
                else {
                    NSString *attributeName  = @"name";
                    NSCharacterSet *wildcards = [NSCharacterSet characterSetWithCharactersInString:@"?*"];
                    NSRange wildcardsPresent = [self.filterText rangeOfCharacterFromSet:wildcards];
                    
                    if (wildcardsPresent.location == NSNotFound)  // Wildcard not presents
                        predicate   = [NSPredicate predicateWithFormat:@"%K contains[cd] %@",
                                       attributeName, self.filterText];
                    else
                        predicate   = [NSPredicate predicateWithFormat:@"%K like[cd] %@",
                                       attributeName, self.filterText];
                }
                //[_treeViewer setFilter:predicate];
            }
        }
        else {
            BranchEnumerator *nodes = [[BranchEnumerator alloc] initWithParent:self.currentNode andDepth: _depth-10];
            TreeItem *item;
            CatalogBranch *catalog = [[CatalogBranch alloc] initWithURL:nil parent:nil];
            //[st setUrl:url]; // Setting the url since the init doesn't. This is a workaround for the time being
            //[catalog setFilter:[NSPredicate predicateWithFormat:@"SELF.itemType==ItemTypeBranch"]];
            [catalog setCatalogKey:@"date_modified"];
            [catalog setValueTransformer:DateToYearTransformer()];
            while ((item = [nodes nextObject])!=nil) {
                [catalog addTreeItem:item];
            }
            _treeViewer = [[TreeViewer alloc] initWithID:self.viewName viewing:catalog depth: _depth];
        }
    }
    else {
        //self->_displayedItems = nil;
        _treeViewer = nil;
    }
}

-(void) setDepth:(NSInteger)depth {
    self->_depth = depth;
}

#pragma mark - table enumerator selectors

- (TreeItem*) itemAtTableIndex:(NSUInteger)index {
    return [self->_treeViewer itemAtIndex:index];
}

- (NSArray*) itemsAtTableIndexes:(NSIndexSet *)indexSet {
    NSMutableArray *answer = [NSMutableArray array];
    [indexSet enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
        [answer addObject:[self->_treeViewer itemAtIndex:idx]];
    }];
    return answer;
}

- (BOOL) itemAtTableisGroup {
    return [self->_treeViewer isGroup];
}

-(NSString*) groupTitle {
    return [self->_treeViewer groupTitle];
}

- (NSUInteger) tableIndexCount {
    return [self->_treeViewer count];
}

-(NSInteger) indexOfTableItem:(TreeItem *)item {
    assert(false); // TODO:!!! Implement this
    return 0;
}

-(NSIndexSet*) indexesWithHashes:(NSArray *)hashes {
    assert(false); //TODO:!!! Implement this
    /*NSIndexSet *indexes = [self->_displayedItems indexesOfObjectsPassingTest:^(id item, NSUInteger index, BOOL *stop){
        //NSLog(@"setTableViewSelectedURLs %@ %lu", [item path], index);
        if ([item isKindOfClass:[TreeItem class]] && [hashes containsObject:[item hashObject]])
            return YES;
        else
            return NO;
    }];
    return indexes;*/
    return nil;
}

-(void) insertedItem:(id)item atTableRow:(NSInteger)row {
    assert(false); //TODO:!!! Implement this
    /*if (row < 0) { // will append
        [self->_displayedItems addObject:item];
    }
    else {
        [self->_displayedItems insertObject:item atIndex:row];
    }*/
}


/*-(NSUInteger) linearIndexForIndexPath:(NSIndexPath*) indexPath {
    if (indexPath.section == 0) {
        return indexPath.item;
    }
    else if (indexPath.section < self->sectionCount) {
        // Adding one because the section itself needs to be discounted
        return self->sectionIndexes[indexPath.section-1] + indexPath.item + 1;
    }
    else {
        NSAssert(NO,@"IconViewController.linearIndexForIndexPath: - Error! section number greater than expected");
        return 0;
    }
}

-(NSIndexPath*) indexPathForLinearIndex:(NSUInteger) linearIndex {
    NSUInteger section = 0;
    NSUInteger item;
    while (linearIndex >= self->sectionIndexes[section]) {
        section++;
        if (section > self->sectionCount) {
            NSAssert(NO,@"IconViewController.indexPathForLinearIndex: - Error! section number greater than expected");
            return nil;
        }
    }
    if (section==0) {
        item = linearIndex;
    }
    else {
        // Subtracting one because of the group needs to be discounted
        item = linearIndex-self->sectionIndexes[section-1] - 1;
    }
    return [NSIndexPath indexPathForItem:item inSection:section];
}
*/
#pragma mark - collection enumerator selectors

- (TreeItem*) itemAtIndexPath:(NSIndexPath*)indexPath {
    return [_treeViewer itemAtIndexPath:indexPath];
}

- (NSIndexPath*) indexPathOfItem:(TreeItem*) item {
    assert(false); //TODO:!!! Implement this
    return nil;
}

- (NSUInteger) sectionCount {
    if (_depth <=1)
        return 1;
    else {
        return _treeViewer.groupCount;
    }
}

- (NSUInteger) itemCountAtSection:(NSUInteger)section {
    return [_treeViewer itemCountAtSection:section];
}

-(NSSet<NSIndexPath*>*) indexPathsWithHashes:(NSArray *)hashes {
//    NSMutableSet<NSIndexPath*> *selectIndexPaths = [[NSMutableSet alloc] initWithCapacity:hashes.count];
//    NSUInteger section=0, nItem=0;
//    NSUInteger idx=0;
//    for (id item in self->_displayedItems ) {
//        if ([item isKindOfClass:[TreeItem class]] && [hashes containsObject:[(TreeItem*)item hashObject]]) {
//            // Advance to the good section
//            while (idx >= self->sectionIndexes[section])
//                section++;
//            if (section==0)
//                nItem = idx;
//            else
//                nItem = idx - self->sectionIndexes[section-1];
//            NSIndexPath *indexPath = [NSIndexPath indexPathForItem:nItem inSection:section];
//            [selectIndexPaths addObject:indexPath];
//        }
//        idx++;
//    }
//    return selectIndexPaths;
    assert(false); //TODO:!!! Implement this
    return nil;
}

- (void) insertedItem:(id)item atIndexPath:(NSIndexPath *)indexPath {
//    NSUInteger linearIndex = [self linearIndexForIndexPath:indexPath];
//    [self->_displayedItems insertObject:item atIndex:linearIndex];
    assert(false); //TODO:!!! Implement this
}

#pragma mark - sort Descriptor selectors

- (void) removeSortOnField:(NSString*)field {
    for (NSSortDescriptor<MySortDescriptorProtocol> *i in self.sortAndGroupDescriptors) {
        if ([i.field isEqualToString:field] ) {
            [self.sortAndGroupDescriptors removeObject:i];
            return;
        }
    }
}

-(NSSortDescriptor*) sortDescriptorForFieldID:(NSString*)fieldID {
    NSString * key = keyForFieldID(fieldID);
    for (NSSortDescriptor* desc in self.sortAndGroupDescriptors) {
        if ([desc.key isEqualToString:key]) {
            return desc;
        }
    }
    return nil;
}


- (void) makeSortOnFieldID:(NSString*)fieldID ascending:(BOOL)ascending grouping:(BOOL)grouping {
    if (self.sortAndGroupDescriptors==nil) {
        self.sortAndGroupDescriptors = [NSMutableArray arrayWithCapacity:1];
    }

    NSSortDescriptor<MySortDescriptorProtocol> *sortDesc;
    if ([fieldID isEqualToString:SORT_FOLDERS_FIRST_FIELD_ID])
        sortDesc = [[FoldersFirstSortDescriptor alloc] init];
    else
        sortDesc = [[NodeSortDescriptor alloc] initWithField:fieldID ascending:ascending grouping:grouping];

    // Removes the key if it was already existing in the remaining of the array
    [self removeSortOnField:fieldID];

    NSInteger i=0;
    if (grouping==NO) {
        // Will insert after the first non grouping descriptor
        while (i < [self.sortAndGroupDescriptors count]) {
            if (![(id<MySortDescriptorProtocol>)self.sortAndGroupDescriptors[i] isGrouping])
                break;
            i++;
        }
    }
    else {
        // First Remove all  groupings
        while ([self.sortAndGroupDescriptors count]!=0) {
            if ([(id<MySortDescriptorProtocol>)self.sortAndGroupDescriptors[i] isGrouping])
                [self.sortAndGroupDescriptors removeObjectAtIndex:0];
            else
                break;
        }
        // i = 0 => will insert on the first element of the array
    }
    [self.sortAndGroupDescriptors insertObject:sortDesc atIndex:i];
}

-(void) removeGroupings {
    NSUInteger i = 0;
    while (i < [self.sortAndGroupDescriptors count]) {
        NSSortDescriptor<MySortDescriptorProtocol> *sortDesc = [self.sortAndGroupDescriptors objectAtIndex:i];
        if ([sortDesc isGrouping] ) {
            [self.sortAndGroupDescriptors removeObjectAtIndex:i];
        }
        else {
            i++;
        }
    }
}

-(NSArray*) getSelectedItemsHash {
   NSLog(@"NodeViewController.getSelectedItemsHash: should be overriden");
    return nil;
}

-(void) setSelectionByHashes:(NSArray *) hashes {
   NSLog(@"NodeViewController.setSelectionByHashes: should be overriden");
}

-(NSArray*) getSelectedItems {
    NSLog(@"NodeViewController.getSelectedItems: should be overriden");
    return nil;
}

// Can select the current Node
- (NSArray*)getSelectedItemsForContextualMenu1 {
    NSLog(@"NodeViewController.getSelectedItemsForContextualMenu1: should be overriden");
    return nil;
}

// Doesn't select the current Node
-(NSArray*) getSelectedItemsForContextualMenu2 {
    NSLog(@"NodeViewController.getSelectedItemsForContextualMenu2: should be overriden");
    return nil;
}

-(TreeItem*) getLastClickedItem {
    NSLog(@"NodeViewController.getLastClickedItem: should be overriden");
    return nil;
}

-(void) setupColumns:(NSArray*) columns {
    // Overrided in Table View. Ignored in other views
}

-(NSArray*) columns {
    // Overrided in Table View. Ignored in other views
    return nil;
}

-(void) addColumn:(NSString*) fieldID {
    // Overrided in Table View. Ignored in other views
}

-(void) removeColumn:(NSString*) fieldID {
    // Overrided in Table View. Ignored in other views
}

-(void) loadPreferencesFrom:(NSDictionary*) preferences {
    // Needs to be called from subclasses
    NSArray *sortElements = [preferences objectForKey:USER_DEF_SORT_KEYS];
    [self.sortAndGroupDescriptors removeAllObjects];
    for (NSDictionary *dict in sortElements) {
        NSString *field = [dict objectForKey:@"field"];
        BOOL ascending = [[dict objectForKey:@"ascending"] boolValue];
        BOOL grouping  = [[dict objectForKey:@"grouping"] boolValue];
        NodeSortDescriptor *desc = [[NodeSortDescriptor alloc] initWithField:field ascending:ascending grouping:grouping];
        //NSLog(@"Loading preferences: Field:%@ ascending:%d grouping:%d", field, ascending, grouping);
        [self.sortAndGroupDescriptors addObject:desc];
    }
}

-(void) savePreferences:(NSMutableDictionary*)preferences {
    // Needs to be called from subclasses
    NSMutableArray *sortElements = [[NSMutableArray alloc] initWithCapacity:[self.sortAndGroupDescriptors count]];
    
    for (NSSortDescriptor<MySortDescriptorProtocol>* desc in self.sortAndGroupDescriptors) {
        //NSLog(@"Saving preferences: Field:%@ ascending:%d grouping:%d", desc.field, desc.ascending, desc.isGrouping);
        if ([desc.field isKindOfClass:[NodeSortDescriptor class]]) {
            // This assures that the FoldersFirst sort descriptor is not saved
            [sortElements addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                     desc.field, @"field",
                                     [NSNumber numberWithBool:desc.ascending], @"ascending",
                                     [NSNumber numberWithBool:desc.isGrouping], @"grouping",
                                     nil]];
        }
    }
    
     [preferences setObject:sortElements forKey: USER_DEF_SORT_KEYS];
}

-(void) _startBusyAnimations {
    if (self->animation_needed == YES) {
        [self startBusyAnimations];
        self->animation_needed = NO;
    }
}

-(void) startBusyAnimationsDelayed {
    // Put a timer of 500ms to delay the animations
    // If animations are stopped before 500ms the animations aren't done.
    [self performSelector:@selector(_startBusyAnimations) withObject:nil afterDelay:ANIMATION_DELAY];
    self->animation_needed = YES;
}

-(void) startBusyAnimations {
    //  should be overriden
    self->animation_needed = NO;

}

-(void) stopBusyAnimations {
    //  should be overriden
    self->animation_needed = NO;
}
@end

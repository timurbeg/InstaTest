//
//  PopularMediaController.m
//  Raminstag
//
//  Created by Timur on 18/12/14.
//  Copyright (c) 2014 TimCo. All rights reserved.
//

#import "HashtagController.h"
#import "CollectionCell.h"
#import "AppDelegate.h"
#import "ViewUtils.h"
#import "InstagramEngine.h"
#import "LXReorderableCollectionViewFlowLayout.h"
#import "InfiniteScrollController.h"

@interface HashtagController () {
    
    CGFloat old_origin;
}

@property (nonatomic, strong) NSMutableArray *mediaArray;
@property (nonatomic, assign) BOOL downloading;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSString *tagString;

@end

@implementation HashtagController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    _tagString = @"";
    
    self.title = @"InstaTest";
    self.view.backgroundColor = [UIColor whiteColor];

    self.mediaArray = [NSMutableArray arrayWithCapacity:0];
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];

    [self configureLeftBarButton];
    
    UIImage *btnImage = [UIImage imageNamed:@"sb-grid-selected"];
    _rightBtnItem = [[UIBarButtonItem alloc] initWithImage:btnImage style:UIBarButtonItemStylePlain target:self action:@selector(showPopover:)];
    self.navigationItem.rightBarButtonItem = _rightBtnItem;
    
    // Remove that 1px line from UINavigationBar in iOS7 https://gist.github.com/apisit/5893320
    [self.navigationController.navigationBar.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:NSClassFromString(@"_UINavigationBarBackground")]){
            UIView* v = obj;
            if ([v.subviews count] > 1) {
                [[v.subviews objectAtIndex:1] removeFromSuperview];
            }
            *stop=YES;
        }
    }];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.f, 0.f, kPortraitWidth, kBarPortraitHeight)];
    _searchBar.placeholder = @"Hashtag";
    _searchBar.text = @"selfie";
    _searchBar.delegate = self;
    _searchBar.backgroundColor = [UIColor magentaColor];
    _searchBar.tintColor = [UIColor whiteColor];
    _searchBar.backgroundImage = [UIImage new];
    
    LXReorderableCollectionViewFlowLayout *layout = [LXReorderableCollectionViewFlowLayout new];
    layout.minimumLineSpacing = 5.f;
    layout.minimumInteritemSpacing = 5.f;

    _feedType = FeedTypeGridx3;
    _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0.f, -kBarPortraitHeight, kPortraitWidth, kPortraitHeight - 20.f) collectionViewLayout:layout];
    [_collectionView setDelegate:self];
    [_collectionView setDataSource:self];
    [_collectionView setClipsToBounds:YES];
    [_collectionView registerClass:[CollectionCell class] forCellWithReuseIdentifier:@"SBInstagramCell"];
    [_collectionView registerClass:[UICollectionReusableView class] forSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"footer"];
    [_collectionView setBackgroundColor:[UIColor whiteColor]];
    [_collectionView setContentInset:UIEdgeInsetsMake(5.f + 2 * kBarPortraitHeight, 5.f, 5.f, 5.f)];
    [_collectionView setAlwaysBounceVertical:YES];
    [_collectionView setAllowsMultipleSelection:YES];

    [self.view addSubview:_collectionView];
    [self.view addSubview:_searchBar];

    self.fullScreenScroll = [[YIFullScreenScroll alloc] initWithViewController:self scrollView:_collectionView style:YIFullScreenScrollStyleFacebook];
    self.fullScreenScroll.delegate = self;

    if (![[InstagramEngine sharedEngine] accessToken]) {
        [[InstagramEngine sharedEngine] checkAccesTokenWithBlock:^(NSError *error) {
            
            if (error) {
                DLog(@"%@", [error description]);
            }
            
            [[InstagramEngine sharedEngine] getSelfUserDetailsWithSuccess:^(InstagramUser *userDetail) {
                DLog(@"user details - %@", userDetail.username);
                [self fetchMedia];
            } failure:^(NSError *error) {
                DLog(@"%@", [error description]);
            }];
        }];
    } else {
        [self fetchMedia];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)configureLeftBarButton {
    
    if (self.downloading) {
        
        UIActivityIndicatorView *preloader = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [preloader startAnimating];
        UIBarButtonItem *preloaderItem = [[UIBarButtonItem alloc] initWithCustomView:preloader];
        self.navigationItem.leftBarButtonItem = preloaderItem;

    } else {
        
        UIBarButtonItem *refreshBtnItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshMedia)];
        self.navigationItem.leftBarButtonItem = refreshBtnItem;
    }
}

#pragma mark - action methods

- (void)refreshMedia {
    
    [self.mediaArray removeAllObjects];
    [_collectionView reloadData];
    [_collectionView.collectionViewLayout invalidateLayout];

    [self fetchMedia];
    [self configureLeftBarButton];
}

- (void)fetchMedia {

    if (![[InstagramEngine sharedEngine] accessToken])
        return;

    if ([self.mediaArray count] > 0 && !_paginationInfo)
        return;
    
    __weak typeof(self) weakSelf = self;
    self.downloading = YES;
    if (!self.activityIndicator.isAnimating)
        [self.activityIndicator startAnimating];
    
    if ([self.mediaArray count] == 0) {
        
        [[InstagramEngine sharedEngine] getMediaWithTagName:_searchBar.text withSuccess:^(NSArray *media, InstagramPaginationInfo *paginationInfo) {
            
            [weakSelf.activityIndicator stopAnimating];
            if (media.count != 0) {
                _paginationInfo = paginationInfo;
                [self.mediaArray addObjectsFromArray:media];
                if (!_searchBar.isFirstResponder) {
                    [_collectionView reloadData];
                }
            } else {
                _paginationInfo = nil;
            }
            [weakSelf.activityIndicator stopAnimating];
            weakSelf.downloading = NO;
            [weakSelf configureLeftBarButton];
            
        } failure:^(NSError *error) {
            DLog(@"%@", [error description]);
        }];
        
    } else if (_paginationInfo) {
        
        [[InstagramEngine sharedEngine]
         getPaginatedItemsForInfo:_paginationInfo
         withSuccess:^(NSArray *media, InstagramPaginationInfo *paginationInfo) {
             
             _paginationInfo = paginationInfo;
             
             if (media.count == 0) {
                 
                 [weakSelf.activityIndicator stopAnimating];
                 [_collectionView reloadData];
                 
             } else {
                 
                 NSUInteger a = [self.mediaArray count];
                 [weakSelf.mediaArray addObjectsFromArray:media];
                 
                 NSMutableArray *arr = [NSMutableArray arrayWithCapacity:0];
                 [media enumerateObjectsUsingBlock:^(id obj, NSUInteger idx,
                                                     BOOL *stop) {
                     NSUInteger b = a + idx;
                     NSIndexPath *path =
                     [NSIndexPath indexPathForItem:b inSection:0];
                     [arr addObject:path];
                 }];
                 
                 [_collectionView performBatchUpdates:^{
                     [_collectionView insertItemsAtIndexPaths:arr];
                 } completion:nil];
             }
             
             weakSelf.downloading = NO;
         }
         
         failure:^(NSError *error) { DLog(@"%@", [error description]); }];
    }
}

- (void)showPopover:(id)sender {
    
    [_searchBar resignFirstResponder];
    
    _popover = [PopoverView showPopoverAtPoint:CGPointMake(kPortraitWidth - 5.f, 34)
                                        inView:self.navigationController.navigationBar
                               withStringArray:@[@"Table", @"Grid x2", @"Grid x3"]
                                withImageArray:@[[UIImage imageNamed:@"sb-table-selected"],[UIImage imageNamed:@"sb-grid-2-selected"], [UIImage imageNamed:@"sb-grid-selected"]]
                                      delegate:self];
    
}

#pragma mark - PopoverViewDelegate Methods

- (void)popoverView:(PopoverView *)popoverView didSelectItemAtIndex:(NSInteger)index
{
    int old_type = _feedType;
    // Figure out which string was selected, store in "string"
    _feedType = (int)index + 1;
    switch (_feedType) {
        case FeedTypeTable:
            _rightBtnItem.image = [UIImage imageNamed:@"sb-table-selected"];
            break;
        case FeedTypeGridx2:
            _rightBtnItem.image = [UIImage imageNamed:@"sb-grid-2-selected"];
            break;
        case FeedTypeGridx3:
            _rightBtnItem.image = [UIImage imageNamed:@"sb-grid-selected"];
            break;
        default:
            break;
    }
    
    // Show a success image, with the string from the array
    [popoverView showImage:[UIImage imageNamed:@"success"] withMessage:@"OK"];
    
    // Dismiss the PopoverView after 0.5 seconds
    [popoverView performSelector:@selector(dismiss) withObject:nil afterDelay:0.3f];
    
    if (old_type != _feedType) {
        [_collectionView reloadData];
    }
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView
{
    //    NSLog(@"%s", __PRETTY_FUNCTION__);
}

#pragma mark - UISearchBar delegate methods

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {

    _tagString = searchText;
    
    if ([self.mediaArray count]) {
        [self.mediaArray removeAllObjects];
    }
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {

    if (_collectionView.scrollEnabled) {
        [self performBlock:^{
            
            searchBar.showsCancelButton = YES;
            _collectionView.scrollEnabled = NO;
            [[_collectionView collectionViewLayout] invalidateLayout];

            _searchBar.frame = CGRectMake(0.f, 0.f, kPortraitWidth, kBarPortraitHeight);
            
        } afterDelay:0.5];
    }
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    
    searchBar.showsCancelButton = YES;
    [searchBar setShowsCancelButton:NO];
    _collectionView.scrollEnabled = YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {

    searchBar.text = @"";
    searchBar.showsCancelButton = NO;
    [searchBar resignFirstResponder];
    
    [self performBlock:^{

        [_collectionView reloadData];
        _collectionView.scrollEnabled = YES;
        [[_collectionView collectionViewLayout] invalidateLayout];

        _searchBar.frame = CGRectMake(0.f, 0.f, kPortraitWidth, kBarPortraitHeight);
        
    } afterDelay:0.5];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    
    _collectionView.scrollEnabled = YES;
    [_searchBar resignFirstResponder];
    [self enableControlsInView:_searchBar];
    [self startSearch];
}

- (void)enableControlsInView:(UIView *)view
{
    for (id subview in view.subviews) {
        if ([subview isKindOfClass:[UIControl class]]) {
            [subview setEnabled:YES];
        }
        [self enableControlsInView:subview];
    }
}

- (void)startSearch {
    
    UIView *preloaderView = [[UIView alloc] initWithFrame:CGRectMake(0.f, 0.f, kPortraitWidth, 40.f)];
    UIActivityIndicatorView *preloader = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [preloader startAnimating];
    [preloader setCenter:preloaderView.center];
    [preloaderView addSubview:preloader];
    
    [self fetchMedia];
}


#pragma mark - orientation update

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [_collectionView.collectionViewLayout invalidateLayout];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [_collectionView reloadItemsAtIndexPaths:[_collectionView indexPathsForVisibleItems]];
    [_collectionView performBatchUpdates:nil completion:nil];
}


#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section {
    return [self.mediaArray count];
}


#pragma mark - UICollectionViewDelegate

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CollectionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"SBInstagramCell" forIndexPath:indexPath];
    
    if ([self.mediaArray count] > 0) {
        InstagramMedia *media = [self.mediaArray objectAtIndex:indexPath.row];
        cell.indexPath = indexPath;
        cell.showOnePicturePerRow = (_feedType == FeedTypeTable);
        [cell setMedia:media andIndexPath:indexPath];
    }
    
    if (indexPath.row == [self.mediaArray count] - 1 && !self.downloading) {
        [self fetchMedia];
    }
    
    return cell;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section
{
    if (!self.downloading) {
        return CGSizeZero;
    }
    return CGSizeMake(CGRectGetWidth(self.view.frame), 40);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath{

    if (kind == UICollectionElementKindSectionFooter) {
        
        UICollectionReusableView *foot = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"footer" forIndexPath:indexPath];

        if (!self.downloading){
            
            [foot.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
            [foot setHidden:YES];
            
        } else {
            
            CGPoint center = self.activityIndicator.center;
            center.x = foot.center.x;
            center.y = 20;
            self.activityIndicator.center = center;
            [foot addSubview:self.activityIndicator];
        }
        
        return foot;
    }
    
    return nil;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [_searchBar resignFirstResponder];
    [self enableControlsInView:_searchBar];
    
    InstagramMedia *media = self.mediaArray[indexPath.row];
    [self showMedia:media];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    
    if (_feedType == FeedTypeTable) {
        return;
    }
}

- (void)collectionView:(UICollectionView *)collectionView itemAtIndexPath:(NSIndexPath *)fromIndexPath willMoveToIndexPath:(NSIndexPath *)toIndexPath {
    id object = [self.mediaArray objectAtIndex:fromIndexPath.item];
    [self.mediaArray removeObjectAtIndex:fromIndexPath.item];
    [self.mediaArray insertObject:object atIndex:toIndexPath.item];
}

- (void)showMedia:(InstagramMedia *)media {
    
    InfiniteScrollController *scrollController = [[InfiniteScrollController alloc] init];
    scrollController.items = self.mediaArray;
    scrollController.currentIndex = [self.mediaArray indexOfObject:media];
    scrollController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:scrollController];
    [self presentViewController:navController animated:YES completion:nil];
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    
    int intervals = _feedType + 1;
    CGFloat frameWidth = (kPortraitWidth - intervals * 5.f) / _feedType;
    return CGSizeMake(frameWidth, frameWidth);
}

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    if (_feedType == FeedTypeTable) {
        return 0;
    } else if (_feedType == FeedTypeGridx2) {
        return 5.f;
    }
    return 5.f;
}

- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    if (_feedType == FeedTypeTable) {
        return 5.f;
    } else if (_feedType == FeedTypeGridx2) {
        return 5.f;
    }
    return 5.f;
}

#pragma mark - YIFullScreenScrollDelegate methods

- (void)fullScreenScrollDidLayoutUIBars:(YIFullScreenScroll *)fullScreenScroll {
    
    CGFloat origin = fullScreenScroll.scrollView.contentOffset.y + 5.f;
    
    BOOL isScrollUp = old_origin < origin;
    
    if (origin < -2 * kBarPortraitHeight) {
        _searchBar.top = 0.f;
    } else if (origin >= -2 * kBarPortraitHeight && origin <= -kBarPortraitHeight) {
        if (isScrollUp) {
            _searchBar.top = -(2 * kBarPortraitHeight + origin);
        } else {
            _searchBar.top = fullScreenScroll.navigationBar.bottom - kBarPortraitHeight - 20.f;
        }
    } else if (origin >= -kBarPortraitHeight ) {
        _searchBar.top = fullScreenScroll.navigationBar.bottom - kBarPortraitHeight - 20.f;
    }
    
    old_origin = origin;
}

#pragma mark - UIScrollViewDelegate methods

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView
                     withVelocity:(CGPoint)velocity
              targetContentOffset:(inout CGPoint *)targetContentOffset {
    
    if (_collectionView.scrollEnabled) {
        [self.fullScreenScroll autoScrolling];
        
    }
}

@end














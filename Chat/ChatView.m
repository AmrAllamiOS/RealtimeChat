//
// Copyright (c) 2014 Related Code - http://relatedcode.com
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Firebase/Firebase.h>

#import "ProgressHUD.h"
#import "UIImageView+AFNetworking.h"

#import "AppConstant.h"

#import "ChatView.h"

//-------------------------------------------------------------------------------------------------------------------------------------------------
@interface ChatView()
{
	NSString *chatroom;
	NSDictionary *userinfo;

	BOOL initialized;
	FirebaseHandle handle;

	NSMutableArray *users;
	NSMutableArray *messages;

	UIImageView *outgoingBubbleImageView;
	UIImageView *incomingBubbleImageView;
}
@end
//-------------------------------------------------------------------------------------------------------------------------------------------------

@implementation ChatView

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (id)initWith:(NSString *)Chatroom Userinfo:(NSDictionary *)Userinfo
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	self = [super init];
	chatroom = [Chatroom copy];
	userinfo = [Userinfo copy];
	return self;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewDidLoad
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewDidLoad];
	self.title = chatroom;

	users = [[NSMutableArray alloc] init];
	messages = [[NSMutableArray alloc] init];

	self.sender = [userinfo valueForKey:@"uid"];

	outgoingBubbleImageView = [JSQMessagesBubbleImageFactory outgoingMessageBubbleImageViewWithColor:[UIColor jsq_messageBubbleLightGrayColor]];
	incomingBubbleImageView = [JSQMessagesBubbleImageFactory incomingMessageBubbleImageViewWithColor:[UIColor jsq_messageBubbleGreenColor]];

	[self loadMessages];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)viewDidAppear:(BOOL)animated
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[super viewDidAppear:animated];

	self.collectionView.collectionViewLayout.springinessEnabled = YES;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)loadMessages
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	[ProgressHUD show:@"Loading..." Interaction:NO];
	
	initialized = NO;
	self.firebase = [[Firebase alloc] initWithUrl:[NSString stringWithFormat:@"%@/%@", FIREBASE, chatroom]];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	[self.firebase observeEventType:FEventTypeChildAdded withBlock:^(FDataSnapshot *snapshot)
	{
		NSString *text = [snapshot.value objectForKey:@"text"];
		NSString *uid = [snapshot.value objectForKey:@"uid"];
		NSString *dateStr = [snapshot.value objectForKey:@"date"];

		NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
		[formatter setDateFormat: @"yyyy-MM-dd HH:mm:ss zzz"];
		NSDate *date = [formatter dateFromString:dateStr];
		if (date ==  nil) date = [NSDate date];

		JSQMessage *message = [[JSQMessage alloc] initWithText:text sender:uid date:date];
		[messages addObject:message];

		NSString *image = [snapshot.value objectForKey:@"image"];
		NSString *name = [snapshot.value objectForKey:@"name"];
		[users addObject:@{@"name":name, @"image":image}];

		if (initialized)
		{
			[JSQSystemSoundPlayer jsq_playMessageReceivedSound];
			[self finishReceivingMessage];
		}
	}];
	//---------------------------------------------------------------------------------------------------------------------------------------------
	handle = [self.firebase observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot)
	{
		[self.firebase removeObserverWithHandle:handle];

		if (snapshot.value != [NSNull null])
		{
			[self finishReceivingMessage];
			[ProgressHUD dismiss];
		}
		else [ProgressHUD showError:@"No chat message." Interaction:NO];

		initialized	= YES;
	}];
}

#pragma mark - JSQMessagesViewController method overrides

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)didPressSendButton:(UIButton *)button withMessageText:(NSString *)text sender:(NSString *)sender date:(NSDate *)date
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSString *uid = [userinfo valueForKey:@"uid"];
	NSString *image = [userinfo valueForKey:@"image"];
	NSString *name = [userinfo valueForKey:@"name"];

	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat: @"yyyy-MM-dd HH:mm:ss zzz"];
	NSString *dateStr = [formatter stringFromDate:date];

	[[self.firebase childByAutoId] setValue:@{@"text":text, @"uid":uid, @"date":dateStr, @"image":image, @"name":name}];

	[JSQSystemSoundPlayer jsq_playMessageSentSound];
	[self finishSendingMessage];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)didPressAccessoryButton:(UIButton *)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSLog(@"didPressAccessoryButton");
}

#pragma mark - JSQMessages CollectionView DataSource

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (id<JSQMessageData>)collectionView:(JSQMessagesCollectionView *)collectionView messageDataForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [messages objectAtIndex:indexPath.item];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView bubbleImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	JSQMessage *message = [messages objectAtIndex:indexPath.item];
	if ([[message sender] isEqualToString:self.sender])
	{
		return [[UIImageView alloc] initWithImage:outgoingBubbleImageView.image highlightedImage:outgoingBubbleImageView.highlightedImage];
	}
	else return [[UIImageView alloc] initWithImage:incomingBubbleImageView.image highlightedImage:incomingBubbleImageView.highlightedImage];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (UIImageView *)collectionView:(JSQMessagesCollectionView *)collectionView avatarImageViewForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSDictionary *user = [users objectAtIndex:indexPath.row];

	UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"blank_avatar"]];
	[imageView setImageWithURL:[NSURL URLWithString:user[@"image"]] placeholderImage:nil];
	imageView.layer.cornerRadius = imageView.frame.size.width/2;
	imageView.layer.masksToBounds = YES;

	return imageView;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if (indexPath.item % 3 == 0)
	{
		JSQMessage *message = [messages objectAtIndex:indexPath.item];
		return [[JSQMessagesTimestampFormatter sharedFormatter] attributedTimestampForDate:message.date];
	}
	return nil;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	JSQMessage *message = [messages objectAtIndex:indexPath.item];
	if ([message.sender isEqualToString:self.sender])
	{
		return nil;
	}
	
	if (indexPath.item - 1 > 0)
	{
		JSQMessage *previousMessage = [messages objectAtIndex:indexPath.item - 1];
		if ([[previousMessage sender] isEqualToString:message.sender])
		{
			return nil;
		}
	}

	NSDictionary *user = [users objectAtIndex:indexPath.row];
	return [[NSAttributedString alloc] initWithString:user[@"name"]];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSAttributedString *)collectionView:(JSQMessagesCollectionView *)collectionView attributedTextForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return nil;
}

#pragma mark - UICollectionView DataSource

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return [messages count];
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (UICollectionViewCell *)collectionView:(JSQMessagesCollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	JSQMessagesCollectionViewCell *cell = (JSQMessagesCollectionViewCell *)[super collectionView:collectionView cellForItemAtIndexPath:indexPath];
	
	JSQMessage *message = [messages objectAtIndex:indexPath.item];
	if ([message.sender isEqualToString:self.sender])
	{
		cell.textView.textColor = [UIColor blackColor];
	}
	else
	{
		cell.textView.textColor = [UIColor whiteColor];
	}
	
	cell.textView.linkTextAttributes = @{NSForegroundColorAttributeName:cell.textView.textColor,
										 NSUnderlineStyleAttributeName:@(NSUnderlineStyleSingle | NSUnderlinePatternSolid)};
	
	return cell;
}

#pragma mark - JSQMessages collection view flow layout delegate

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	if (indexPath.item % 3 == 0)
	{
		return kJSQMessagesCollectionViewCellLabelHeightDefault;
	}
	return 0.0f;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForMessageBubbleTopLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	JSQMessage *message = [messages objectAtIndex:indexPath.item];
	if ([[message sender] isEqualToString:self.sender])
	{
		return 0.0f;
	}
	
	if (indexPath.item - 1 > 0)
	{
		JSQMessage *previousMessage = [messages objectAtIndex:indexPath.item - 1];
		if ([[previousMessage sender] isEqualToString:[message sender]])
		{
			return 0.0f;
		}
	}
	return kJSQMessagesCollectionViewCellLabelHeightDefault;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (CGFloat)collectionView:(JSQMessagesCollectionView *)collectionView
				   layout:(JSQMessagesCollectionViewFlowLayout *)collectionViewLayout heightForCellBottomLabelAtIndexPath:(NSIndexPath *)indexPath
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	return 0.0f;
}

//-------------------------------------------------------------------------------------------------------------------------------------------------
- (void)collectionView:(JSQMessagesCollectionView *)collectionView
				header:(JSQMessagesLoadEarlierHeaderView *)headerView didTapLoadEarlierMessagesButton:(UIButton *)sender
//-------------------------------------------------------------------------------------------------------------------------------------------------
{
	NSLog(@"didTapLoadEarlierMessagesButton");
}

@end

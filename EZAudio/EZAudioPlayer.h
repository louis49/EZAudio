//
//  EZAudioPlayer.h
//  EZAudio
//
//  Created by Syed Haris Ali on 1/16/14.
//  Copyright (c) 2014 Syed Haris Ali. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import <Foundation/Foundation.h>
#import "TargetConditionals.h"
#import "EZAudioFile.h"

#if TARGET_OS_IPHONE
  #import <AVFoundation/AVFoundation.h>
#elif TARGET_OS_MAC
#endif

@class EZAudioPlayer;

//------------------------------------------------------------------------------
#pragma mark - Constants
//------------------------------------------------------------------------------

FOUNDATION_EXPORT UInt32 const EZAudioPlayerMaximumFramesPerSlice;

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlayerDelegate
//------------------------------------------------------------------------------

/**
 The EZAudioPlayerDelegate provides event callbacks for the EZAudioPlayer. These type of events are triggered by changes in the EZAudioPlayer's state and allow someone implementing the EZAudioPlayer to more easily update their user interface. Events are triggered anytime the EZAudioPlayer resumes/pauses playback, reaches the end of the file, reads audio data and converts it to float data visualizations (using the EZAudioFile), and updates its cursor position within the audio file during playback (use this for the play position on a slider on the user interface).
 @warning These callbacks don't necessarily occur on the main thread so make sure you wrap any UI code in a GCD block like: dispatch_async(dispatch_get_main_queue(), ^{ // Update UI });
 */
@protocol EZAudioPlayerDelegate <NSObject>

@optional
/**
 Triggered by the EZAudioPlayer when the playback has been resumed or started.
 @param audioPlayer The instance of the EZAudioPlayer that triggered the event
 @param audioFile   The instance of the EZAudioFile that the event was triggered from
 */
- (void)audioPlayer:(EZAudioPlayer *)audioPlayer didResumePlaybackOnAudioFile:(EZAudioFile *)audioFile;

///-----------------------------------------------------------

/**
 Triggered by the EZAudioPlayer when the playback has been paused.
 @param audioPlayer The instance of the EZAudioPlayer that triggered the event
 @param audioFile   The instance of the EZAudioFile that the event was triggered from
 */
- (void)audioPlayer:(EZAudioPlayer *)audioPlayer didPausePlaybackOnAudioFile:(EZAudioFile *)audioFile;

///-----------------------------------------------------------

/**
 Triggered by the EZAudioPlayer when the output has reached the end of the EZAudioFile it's playing. If the EZAudioPlayer has its `shouldLoop` property set to true this will trigger, but playback will continue to loop once its hit the end of the audio file.
 @param audioPlayer The instance of the EZAudioPlayer that triggered the event
 @param audioFile   The instance of the EZAudioFile that the event was triggered from
 */
- (void)audioPlayer:(EZAudioPlayer *)audioPlayer reachedEndOfAudioFile:(EZAudioFile *)audioFile;

///-----------------------------------------------------------

/**
 Triggered by the EZAudioPlayer's internal EZAudioFile's EZAudioFileDelegate callback and notifies the delegate of the read audio data as a float array instead of a buffer list. Common use case of this would be to visualize the float data using an audio plot or audio data dependent OpenGL sketch.
 @param audioPlayer The instance of the EZAudioPlayer that triggered the event
 @param buffer           A float array of float arrays holding the audio data. buffer[0] would be the left channel's float array while buffer[1] would be the right channel's float array in a stereo file.
 @param bufferSize       The length of the buffers float arrays
 @param numberOfChannels The number of channels. 2 for stereo, 1 for mono.
 @param audioFile   The instance of the EZAudioFile that the event was triggered from
 */
- (void)   audioPlayer:(EZAudioPlayer *)audioPlayer
            readAudio:(float **)buffer
       withBufferSize:(UInt32)bufferSize
 withNumberOfChannels:(UInt32)numberOfChannels
          inAudioFile:(EZAudioFile *)audioFile;;

///-----------------------------------------------------------

/**
 Triggered by EZAudioPlayer's internal EZAudioFile's EZAudioFileDelegate callback and notifies the delegate of the current playback position. The framePosition provides the current frame position and can be calculated against the EZAudioPlayer's total frames using the `totalFrames` function from the EZAudioPlayer.
 @param audioPlayer The instance of the EZAudioPlayer that triggered the event
 @param framePosition The new frame index as a 64-bit signed integer
 @param audioFile   The instance of the EZAudioFile that the event was triggered from
 */
- (void)audioPlayer:(EZAudioPlayer *)audioPlayer
    updatedPosition:(SInt64)framePosition
        inAudioFile:(EZAudioFile *)audioFile;

@end

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlayer
//------------------------------------------------------------------------------

/**
 The EZAudioPlayer acts as the master delegate (the EZAudioFileDelegate) over whatever EZAudioFile it is using for playback. Classes that want to get the EZAudioFileDelegate callbacks should implement the EZAudioPlayer's EZAudioPlayerDelegate on the EZAudioPlayer instance.
 */
@interface EZAudioPlayer : NSObject <EZAudioFileDelegate>

//------------------------------------------------------------------------------
#pragma mark - Properties
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Properties
///-----------------------------------------------------------

/**
 The EZAudioPlayerDelegate that will handle the audio player callbacks
 */
@property (nonatomic, weak) id<EZAudioPlayerDelegate> delegate;

//------------------------------------------------------------------------------

/**
 A BOOL indicating whether the player should loop the file
 */
@property (nonatomic, assign) BOOL shouldLoop;

//------------------------------------------------------------------------------
#pragma mark - Initializers
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Initializers
///-----------------------------------------------------------

/**
 Initializes the EZAudioPlayer with an EZAudioFile instance. This does not use the EZAudioFile by reference, but instead creates a separate EZAudioFile instance with the same file at the given file path provided by the internal NSURL to use for internal seeking so it doesn't cause any locking between the caller's instance of the EZAudioFile.
 @param audioFile The instance of the EZAudioFile to use for initializing the EZAudioPlayer
 @return The newly created instance of the EZAudioPlayer
 */
- (instancetype)initWithAudioFile:(EZAudioFile *)audioFile;

/**
 Initializes the EZAudioPlayer with an EZAudioFile instance and provides a way to assign the EZAudioPlayerDelegate on instantiation. This does not use the EZAudioFile by reference, but instead creates a separate EZAudioFile instance with the same file at the given file path provided by the internal NSURL to use for internal seeking so it doesn't cause any locking between the caller's instance of the EZAudioFile.
 @param audioFile The instance of the EZAudioFile to use for initializing the EZAudioPlayer
 @param delegate The receiver that will act as the EZAudioPlayerDelegate. Set to nil if it should have no delegate or use the initWithEZAudioFile: function instead.
 @return The newly created instance of the EZAudioPlayer
 */
- (instancetype)initWithAudioFile:(EZAudioFile *)audioFile
                         delegate:(id<EZAudioPlayerDelegate>)delegate;

/**
 Initializes the EZAudioPlayer with an NSURL instance representing the file path of the audio file.
 @param url The NSURL instance representing the file path of the audio file.
 @return The newly created instance of the EZAudioPlayer
 */
- (instancetype)initWithURL:(NSURL*)url;

/**
 Initializes the EZAudioPlayer with an NSURL instance representing the file path of the audio file and a caller to assign as the EZAudioPlayerDelegate on instantiation.
 @param url The NSURL instance representing the file path of the audio file.
 @param delegate The receiver that will act as the EZAudioPlayerDelegate. Set to nil if it should have no delegate or use the initWithEZAudioFile: function instead.
 @return The newly created instance of the EZAudioPlayer
 */
- (instancetype)initWithURL:(NSURL*)url
                   delegate:(id<EZAudioPlayerDelegate>)delegate;


#pragma mark - Class Initializers
///-----------------------------------------------------------
/// @name Class Initializers
///-----------------------------------------------------------

/**
 Class initializer that creates the default EZAudioPlayer.
 @return The newly created instance of the EZAudioPlayer
 */
+ (instancetype)audioPlayer;

/**
 Class initializer that creates the EZAudioPlayer with an EZAudioFile instance. This does not use the EZAudioFile by reference, but instead creates a separate EZAudioFile instance with the same file at the given file path provided by the internal NSURL to use for internal seeking so it doesn't cause any locking between the caller's instance of the EZAudioFile.
 @param audioFile The instance of the EZAudioFile to use for initializing the EZAudioPlayer
 @return The newly created instance of the EZAudioPlayer
 */
+ (instancetype)audioPlayerWithAudioFile:(EZAudioFile *)audioFile;

///-----------------------------------------------------------

/**
 Class initializer that creates the EZAudioPlayer with an EZAudioFile instance and provides a way to assign the EZAudioPlayerDelegate on instantiation. This does not use the EZAudioFile by reference, but instead creates a separate EZAudioFile instance with the same file at the given file path provided by the internal NSURL to use for internal seeking so it doesn't cause any locking between the caller's instance of the EZAudioFile.
 @param audioFile The instance of the EZAudioFile to use for initializing the EZAudioPlayer
 @param delegate The receiver that will act as the EZAudioPlayerDelegate. Set to nil if it should have no delegate or use the audioPlayerWithEZAudioFile: function instead.
 @return The newly created instance of the EZAudioPlayer
 */
+ (instancetype)audioPlayerWithAudioFile:(EZAudioFile *)audioFile
                                delegate:(id<EZAudioPlayerDelegate>)delegate;

///-----------------------------------------------------------

/**
 Class initializer that creates the EZAudioPlayer with an NSURL instance representing the file path of the audio file.
 @param url The NSURL instance representing the file path of the audio file.
 @return The newly created instance of the EZAudioPlayer
 */
+ (instancetype)audioPlayerWithURL:(NSURL*)url;

///-----------------------------------------------------------

/**
 Class initializer that creates the EZAudioPlayer with an NSURL instance representing the file path of the audio file and a caller to assign as the EZAudioPlayerDelegate on instantiation.
 @param url The NSURL instance representing the file path of the audio file.
 @param delegate The receiver that will act as the EZAudioPlayerDelegate. Set to nil if it should have no delegate or use the audioPlayerWithURL: function instead.
 @return The newly created instance of the EZAudioPlayer
 */
+ (instancetype)audioPlayerWithURL:(NSURL*)url
                          delegate:(id<EZAudioPlayerDelegate>)delegate;

//------------------------------------------------------------------------------
#pragma mark - Singleton
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Shared Instance
///-----------------------------------------------------------

/**
 The shared instance (singleton) of the audio player. Most applications will only have one instance of the EZAudioPlayer that can be reused with multiple different audio files.
 *  @return The shared instance of the EZAudioPlayer.
 */
+ (instancetype)sharedAudioPlayer;

//------------------------------------------------------------------------------
#pragma mark - Getters
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Properties
///-----------------------------------------------------------

/**
 Provides the EZAudioFile instance that is being used as the datasource for playback. When set it creates a copy of the EZAudioFile provided for internal use. This does not use the EZAudioFile by reference, but instead creates a separate EZAudioFile instance with the same file at the given file path provided by the internal NSURL to use for internal seeking so it doesn't cause any locking between the caller's instance of the EZAudioFile.
 */
@property (nonatomic, readwrite, copy) EZAudioFile *audioFile;

//------------------------------------------------------------------------------

/**
 Provides the current offset in the audio file as an NSTimeInterval (i.e. in seconds).  When setting this it will determine the correct frame offset and perform a `seekToFrame` to the new time offset.
 @warning Make sure the new current time offset is less than the `duration` or you will receive an invalid seek assertion.
 */
@property (nonatomic, readwrite) NSTimeInterval currentTime;

//------------------------------------------------------------------------------

/**
 Provides the duration of the audio file in seconds.
 */
@property (readonly) NSTimeInterval duration;

//------------------------------------------------------------------------------

/**
 Provides the current time as an NSString with the time format MM:SS.
 */
@property (readonly) NSString *formattedCurrentTime;

//------------------------------------------------------------------------------

/**
 Provides the duration as an NSString with the time format MM:SS.
 */
@property (readonly) NSString *formattedDuration;

//------------------------------------------------------------------------------

/**
 Provides the total duration of the audio file in seconds.
 @deprecated This property is deprecated starting in version 0.4.0.
 @note Please use `duration` property instead.
 @return The total duration of the audio file as a Float32.
 */
@property (readonly) NSTimeInterval totalDuration __attribute__((deprecated));;

//------------------------------------------------------------------------------

/**
 Provides a flag indicating whether the EZAudioPlayer has reached the end of the audio file used for playback.
 @return A BOOL indicating whether or not the EZAudioPlayer has reached the end of the file it is using for playback.
 */
@property (readonly) BOOL isEndOfFile;

//------------------------------------------------------------------------------

/**
 Provides the frame index (a.k.a the seek positon) within the audio file being used for playback. This can be helpful when seeking through the audio file.
 @return An SInt64 representing the current frame index within the audio file used for playback.
 */
@property (readonly) SInt64 frameIndex;

//------------------------------------------------------------------------------

/**
 Provides a flag indicating whether the EZAudioPlayer is currently playing back any audio.
 @return A BOOL indicating whether or not the EZAudioPlayer is performing playback,
 */
@property (readonly) BOOL isPlaying;

//------------------------------------------------------------------------------

/**
 Provides the total amount of frames in the current audio file being used for playback.
 @return A SInt64 representing the total amount of frames in the current audio file being used for playback.
 */
@property (readonly) SInt64 totalFrames;

//------------------------------------------------------------------------------

/**
 Provides the file path that's currently being used by the player for playback.
 @return  The NSURL representing the file path of the audio file being used for playback.
 */
@property (nonatomic, copy, readonly) NSURL *url;

//------------------------------------------------------------------------------
#pragma mark - Actions
//------------------------------------------------------------------------------

///-----------------------------------------------------------
/// @name Controlling Playback
///-----------------------------------------------------------

/**
 Starts playback.
 */
- (void)play;

//------------------------------------------------------------------------------

/**
 Loads an EZAudioFile and immediately starts playing it.
 @param audioFile An EZAudioFile to use for immediate playback.
 */
- (void)playAudioFile:(EZAudioFile *)audioFile;

//------------------------------------------------------------------------------

/**
 Pauses playback.
 */
- (void)pause;

//------------------------------------------------------------------------------

/**
 Seeks playback to a specified frame within the internal EZAudioFile. This will notify the EZAudioFileDelegate (if specified) with the audioPlayer:updatedPosition:inAudioFile: function.
 @param frame The new frame position to seek to as a SInt64.
 */
- (void)seekToFrame:(SInt64)frame;

//------------------------------------------------------------------------------
#pragma mark - Subclass
//------------------------------------------------------------------------------

- (AudioStreamBasicDescription)defaultClientFormat;

//------------------------------------------------------------------------------

- (Float64)defaultSampleRate;

//------------------------------------------------------------------------------

/**
 <#Description#>
 */
- (void)cleanupCustomNodes;

//------------------------------------------------------------------------------

/**
 <#Description#>
 @param sourceNode              <#sourceNode description#>
 @param sourceNodeOutputBus     <#sourceNodeOutputBus description#>
 @param destinationNode         <#destinationNode description#>
 @param destinationNodeInputBus <#destinationNodeInputBus description#>
 @param graph                   <#graph description#>
 @return <#return value description#>
 */
- (OSStatus)connectOutputOfSourceNode:(AUNode)sourceNode
                  sourceNodeOutputBus:(UInt32)sourceNodeOutputBus
                    toDestinationNode:(AUNode)destinationNode
              destinationNodeInputBus:(UInt32)destinationNodeInputBus
                              inGraph:(AUGraph)graph;

//------------------------------------------------------------------------------

@end

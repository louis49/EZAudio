//
//  EZAudioPlayer.m
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

#import "EZAudioPlayer.h"
#import "EZAudioUtilities.h"

//------------------------------------------------------------------------------
#pragma mark - Constants
//------------------------------------------------------------------------------

UInt32 const EZAudioPlayerMaximumFramesPerSlice = 4096;

//------------------------------------------------------------------------------
#pragma mark - Data Structures
//------------------------------------------------------------------------------

typedef struct
{
    // stream format params
    AudioStreamBasicDescription clientFormat;
    
    // nodes
    EZAudioNodeInfo converterNodeInfo;
    EZAudioNodeInfo mixerNodeInfo;
    EZAudioNodeInfo outputNodeInfo;
    
    // audio graph
    AUGraph graph;
} EZAudioPlayerInfo;

//------------------------------------------------------------------------------
#pragma mark - Callbacks (Declaration)
//------------------------------------------------------------------------------

OSStatus EZAudioPlayerConverterInputCallback(void                       *inRefCon,
                                             AudioUnitRenderActionFlags *ioActionFlags,
                                             const AudioTimeStamp       *inTimeStamp,
                                             UInt32					     inBusNumber,
                                             UInt32					     inNumberFrames,
                                             AudioBufferList            *ioData);

//------------------------------------------------------------------------------

OSStatus EZAudioPlayerGraphRenderCallback(void                       *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp       *inTimeStamp,
                                          UInt32					  inBusNumber,
                                          UInt32					  inNumberFrames,
                                          AudioBufferList            *ioData);

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlayer (Interface Extension)
//------------------------------------------------------------------------------

@interface EZAudioPlayer ()
@property (nonatomic, assign) EZAudioPlayerInfo *info;
@end

//------------------------------------------------------------------------------
#pragma mark - EZAudioPlayer (Implementation)
//------------------------------------------------------------------------------

@implementation EZAudioPlayer

//------------------------------------------------------------------------------
#pragma mark - Dealloc
//------------------------------------------------------------------------------

- (void)dealloc
{
    [self cleanupCustomNodes];
    self.audioFile = nil;
    free(self.info);
}

//------------------------------------------------------------------------------
#pragma mark - Class Methods
//------------------------------------------------------------------------------

+ (instancetype)audioPlayer
{
    return [[self alloc] init];
}

//------------------------------------------------------------------------------

+ (EZAudioPlayer *)audioPlayerWithAudioFile:(EZAudioFile *)audioFile
{
    return [[self alloc] initWithAudioFile:audioFile];
}

//------------------------------------------------------------------------------

+ (EZAudioPlayer *)audioPlayerWithAudioFile:(EZAudioFile *)audioFile
                                   delegate:(id<EZAudioPlayerDelegate>)delegate
{
    return [[self alloc] initWithAudioFile:audioFile
                                  delegate:delegate];
}

//------------------------------------------------------------------------------

+ (EZAudioPlayer *)audioPlayerWithURL:(NSURL *)url
{
    return [[self alloc] initWithURL:url];
}

//------------------------------------------------------------------------------

+ (EZAudioPlayer *)audioPlayerWithURL:(NSURL *)url
                             delegate:(id<EZAudioPlayerDelegate>)delegate
{
    return [[self alloc] initWithURL:url delegate:delegate];
}

//------------------------------------------------------------------------------
#pragma mark - Initialization
//------------------------------------------------------------------------------

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        self.info = (EZAudioPlayerInfo *)malloc(sizeof(EZAudioPlayerInfo));
        [self setup];
    }
    return self;
}

//------------------------------------------------------------------------------

- (EZAudioPlayer *)initWithAudioFile:(EZAudioFile *)audioFile
{
    return [self initWithAudioFile:audioFile delegate:nil];
}

//------------------------------------------------------------------------------

- (EZAudioPlayer *)initWithAudioFile:(EZAudioFile *)audioFile
                            delegate:(id<EZAudioPlayerDelegate>)delegate
{
    self = [self init];
    if (self)
    {
        self.audioFile = audioFile;
        self.delegate = delegate;
    }
    return self;
}

//------------------------------------------------------------------------------

- (EZAudioPlayer *)initWithURL:(NSURL *)url
{
    return [self initWithURL:url delegate:nil];
}

//------------------------------------------------------------------------------

- (EZAudioPlayer *)initWithURL:(NSURL *)url
                      delegate:(id<EZAudioPlayerDelegate>)delegate
{
    self = [self init];
    if (self)
    {
        self.audioFile = [EZAudioFile audioFileWithURL:url delegate:self];
        self.delegate = delegate;
    }
    return self;
}

//------------------------------------------------------------------------------
#pragma mark - Singleton
//------------------------------------------------------------------------------

+ (instancetype)sharedAudioPlayer
{
    static EZAudioPlayer *player;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        player = [[self alloc] init];
    });
    return player;
}

//------------------------------------------------------------------------------
#pragma mark - Setup
//------------------------------------------------------------------------------

- (void)setup
{
    //
    // Setup the audio graph
    //
    [EZAudioUtilities checkResult:NewAUGraph(&self.info->graph)
                        operation:"Failed to create graph"];
    
    //
    // Add converter node
    //
    AudioComponentDescription converterDescription;
    converterDescription.componentType = kAudioUnitType_FormatConverter;
    converterDescription.componentSubType = kAudioUnitSubType_AUConverter;
    converterDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    [EZAudioUtilities checkResult:AUGraphAddNode(self.info->graph,
                                                 &converterDescription,
                                                 &self.info->converterNodeInfo.node)
                        operation:"Failed to add converter node to audio graph"];
    
    //
    // Add mixer node
    //
    AudioComponentDescription mixerDescription;
    mixerDescription.componentType = kAudioUnitType_Mixer;
#if TARGET_OS_IPHONE
    mixerDescription.componentSubType = kAudioUnitSubType_MultiChannelMixer;
#elif TARGET_OS_MAC
    mixerDescription.componentSubType = kAudioUnitSubType_StereoMixer;
#endif
    mixerDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    [EZAudioUtilities checkResult:AUGraphAddNode(self.info->graph,
                                                 &mixerDescription,
                                                 &self.info->mixerNodeInfo.node)
                        operation:"Failed to add mixer node to audio graph"];
    
    //
    // Add output node
    //
    AudioComponentDescription outputDescription;
    outputDescription.componentType = kAudioUnitType_Output;
#if TARGET_OS_IPHONE
    outputDescription.componentSubType = kAudioUnitSubType_RemoteIO;
#elif TARGET_OS_MAC
    outputDescription.componentSubType = kAudioUnitSubType_DefaultOutput;
#endif
    outputDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    [EZAudioUtilities checkResult:AUGraphAddNode(self.info->graph,
                                                 &outputDescription,
                                                 &self.info->outputNodeInfo.node)
                        operation:"Failed to add output node to audio graph"];
    
    //
    // Open the graph
    //
    [EZAudioUtilities checkResult:AUGraphOpen(self.info->graph)
                        operation:"Failed to open graph"];
    
    //
    // Make node connections
    //
    OSStatus status = [self connectOutputOfSourceNode:self.info->converterNodeInfo.node
                                  sourceNodeOutputBus:0
                                    toDestinationNode:self.info->mixerNodeInfo.node
                              destinationNodeInputBus:0
                                              inGraph:self.info->graph];
    [EZAudioUtilities checkResult:status
                        operation:"Failed to connect output of source node to destination node in graph"];
    
    //
    // Connect mixer to output
    //
    [EZAudioUtilities checkResult:AUGraphConnectNodeInput(self.info->graph,
                                                          self.info->mixerNodeInfo.node,
                                                          0,
                                                          self.info->outputNodeInfo.node,
                                                          0)
                        operation:"Failed to connect mixer node to output node"];
    
    //
    // Get the audio units
    //
    [EZAudioUtilities checkResult:AUGraphNodeInfo(self.info->graph,
                                                  self.info->converterNodeInfo.node,
                                                  &converterDescription,
                                                  &self.info->converterNodeInfo.audioUnit)
                        operation:"Failed to get converter audio unit"];
    [EZAudioUtilities checkResult:AUGraphNodeInfo(self.info->graph,
                                                  self.info->mixerNodeInfo.node,
                                                  &mixerDescription,
                                                  &self.info->mixerNodeInfo.audioUnit)
                        operation:"Failed to get mixer audio unit"];
    [EZAudioUtilities checkResult:AUGraphNodeInfo(self.info->graph,
                                                  self.info->outputNodeInfo.node,
                                                  &outputDescription,
                                                  &self.info->outputNodeInfo.audioUnit)
                        operation:"Failed to get output audio unit"];
    
    //
    // Add a node input callback for the converter node
    //
    AURenderCallbackStruct converterCallback;
    converterCallback.inputProc = EZAudioPlayerConverterInputCallback;
    converterCallback.inputProcRefCon = (__bridge void *)((EZAudioPlayer *)self);
    [EZAudioUtilities checkResult:AUGraphSetNodeInputCallback(self.info->graph,
                                                              self.info->converterNodeInfo.node,
                                                              0,
                                                              &converterCallback)
                        operation:"Failed to set render callback on converter node"];
    
    //
    // Set stream formats
    //
    self.info->clientFormat = [self defaultClientFormat];
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->converterNodeInfo.audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Output,
                                                       0,
                                                       &self.info->clientFormat,
                                                       sizeof(self.info->clientFormat))
                        operation:"Failed to set output format on converter audio unit"];
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->mixerNodeInfo.audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Input,
                                                       1,
                                                       &self.info->clientFormat,
                                                       sizeof(self.info->clientFormat))
                        operation:"Failed to set output format on mixer audio unit"];
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->mixerNodeInfo.audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Output,
                                                       0,
                                                       &self.info->clientFormat,
                                                       sizeof(self.info->clientFormat))
                        operation:"Failed to set output format on mixer audio unit"];
    
    //
    // Set maximum frames per slice to 4096 to allow playback during
    // lock screen (iOS only?)
    //
    UInt32 maximumFramesPerSlice = EZAudioPlayerMaximumFramesPerSlice;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->mixerNodeInfo.audioUnit,
                                                       kAudioUnitProperty_MaximumFramesPerSlice,
                                                       kAudioUnitScope_Global,
                                                       0,
                                                       &maximumFramesPerSlice,
                                                       sizeof(maximumFramesPerSlice))
                        operation:"Failed to set maximum frames per slice on mixer node"];
    
    //
    // Initialize all the audio units in the graph
    //
    [EZAudioUtilities checkResult:AUGraphInitialize(self.info->graph)
                        operation:"Failed to initialize graph"];
    
    //
    // Add render callback
    //
    [EZAudioUtilities checkResult:AudioUnitAddRenderNotify(self.info->mixerNodeInfo.audioUnit,
                                                           EZAudioPlayerGraphRenderCallback,
                                                           (__bridge void *)(self))
                        operation:"Failed to add render callback"];
}

//------------------------------------------------------------------------------
#pragma mark - Getters
//------------------------------------------------------------------------------

- (NSTimeInterval)currentTime
{
    return [self.audioFile currentTime];
}

//------------------------------------------------------------------------------

- (NSTimeInterval)duration
{
    return [self.audioFile duration];
}

//------------------------------------------------------------------------------

- (NSString *)formattedCurrentTime
{
    return [self.audioFile formattedCurrentTime];
}

//------------------------------------------------------------------------------

- (NSString *)formattedDuration
{
    return [self.audioFile formattedDuration];
}

//------------------------------------------------------------------------------

- (SInt64)frameIndex
{
    return [self.audioFile frameIndex];
}

//------------------------------------------------------------------------------

- (BOOL)isPlaying
{
    Boolean isPlaying;
    [EZAudioUtilities checkResult:AUGraphIsRunning(self.info->graph,
                                                   &isPlaying)
                        operation:"Failed to check if graph is running"];
    return isPlaying;
}

//------------------------------------------------------------------------------

- (float)volume
{
    AudioUnitParameterValue volume;
    [EZAudioUtilities checkResult:AudioUnitGetParameter(self.info->mixerNodeInfo.audioUnit,
                                                        kMultiChannelMixerParam_Volume,
                                                        kAudioUnitScope_Input,
                                                        0,
                                                        &volume)
                        operation:"Failed to get volume from mixer unit"];
    return volume;
}

//------------------------------------------------------------------------------
#pragma mark - Setters
//------------------------------------------------------------------------------

- (void)setAudioFile:(EZAudioFile *)audioFile
{
    _audioFile = [audioFile copy];
    _audioFile.delegate = self;
    AudioStreamBasicDescription inputFormat = _audioFile.clientFormat;
    [EZAudioUtilities checkResult:AudioUnitSetProperty(self.info->converterNodeInfo.audioUnit,
                                                       kAudioUnitProperty_StreamFormat,
                                                       kAudioUnitScope_Input,
                                                       0,
                                                       &inputFormat,
                                                       sizeof(inputFormat))
                        operation:"Failed to set client format on EZAudioPlayer"];
    
}

//------------------------------------------------------------------------------

- (void)setVolume:(float)volume
{
    AudioUnitParameterID param;
#if TARGET_OS_IPHONE
    param = kMultiChannelMixerParam_Volume;
#elif TARGET_OS_MAC
    param = kStereoMixerParam_Volume;
#endif
    [EZAudioUtilities checkResult:AudioUnitSetParameter(self.info->mixerNodeInfo.audioUnit,
                                                        param,
                                                        kAudioUnitScope_Input,
                                                        0,
                                                        volume,
                                                        0)
                        operation:"Failed to set volume on mixer unit"];
}

//------------------------------------------------------------------------------
#pragma mark - Subclass
//------------------------------------------------------------------------------

- (void)cleanupCustomNodes
{
    //
    // Override in subclass
    //
}

//------------------------------------------------------------------------------

- (OSStatus)connectOutputOfSourceNode:(AUNode)sourceNode
                  sourceNodeOutputBus:(UInt32)sourceNodeOutputBus
                    toDestinationNode:(AUNode)destinationNode
              destinationNodeInputBus:(UInt32)destinationNodeInputBus
                              inGraph:(AUGraph)graph
{
    //
    // Default implementation is to just connect the source to destination
    //
    [EZAudioUtilities checkResult:AUGraphConnectNodeInput(graph,
                                                          sourceNode,
                                                          sourceNodeOutputBus,
                                                          destinationNode,
                                                          destinationNodeInputBus)
                        operation:"Failed to connect converter node to mixer node"];
    return noErr;
}

//------------------------------------------------------------------------------

- (AudioStreamBasicDescription)defaultClientFormat
{
    return [EZAudioUtilities stereoFloatNonInterleavedFormatWithSampleRate:[self defaultSampleRate]];
}

//------------------------------------------------------------------------------

- (Float64)defaultSampleRate
{
    return 44100.0f;
}

//------------------------------------------------------------------------------
#pragma mark - Actions
//------------------------------------------------------------------------------

- (void)play
{
    //
    // start the AUGraph
    //
    [EZAudioUtilities checkResult:AUGraphStart(self.info->graph)
                        operation:"Failed to start graph"];
}

//------------------------------------------------------------------------------

- (void)playAudioFile:(EZAudioFile *)audioFile
{
    //
    // stop playing anything that might currently be playing
    //
    [self pause];
    
    //
    // set new stream
    //
    self.audioFile = audioFile;
    
    //
    // begin playback
    //
    [self play];
}

//------------------------------------------------------------------------------

- (void)pause
{
    //
    // stop the AUGraph
    //
    [EZAudioUtilities checkResult:AUGraphStop(self.info->graph)
                        operation:"Failed to stop graph"];
}

//------------------------------------------------------------------------------

- (void)seekToFrame:(SInt64)frame
{
    [self.audioFile seekToFrame:frame];
}

//------------------------------------------------------------------------------

@end

//------------------------------------------------------------------------------
#pragma mark - Callbacks (Implementation)
//------------------------------------------------------------------------------

OSStatus EZAudioPlayerConverterInputCallback(void                       *inRefCon,
                                             AudioUnitRenderActionFlags *ioActionFlags,
                                             const AudioTimeStamp       *inTimeStamp,
                                             UInt32					     inBusNumber,
                                             UInt32					     inNumberFrames,
                                             AudioBufferList            *ioData)
{
    EZAudioPlayer *player = (__bridge EZAudioPlayer *)inRefCon;
    UInt32 bufferSize;
    BOOL eof;
    [player.audioFile readFrames:inNumberFrames
                 audioBufferList:ioData
                      bufferSize:&bufferSize
                             eof:&eof];
    if (eof && player.shouldLoop)
    {
        [player seekToFrame:0];
    }
    else if (eof)
    {
        [player pause];
        [player seekToFrame:0];
    }
    else
    {
        if ([player.delegate respondsToSelector:@selector(audioPlayer:updatedPosition:inAudioFile:)])
        {
            [player.delegate audioPlayer:player
                         updatedPosition:[player frameIndex]
                             inAudioFile:player.audioFile];
        }
    }
    return noErr;
}

//------------------------------------------------------------------------------

OSStatus EZAudioPlayerGraphRenderCallback(void                       *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp       *inTimeStamp,
                                          UInt32					  inBusNumber,
                                          UInt32					  inNumberFrames,
                                          AudioBufferList            *ioData)
{
    EZAudioPlayer *player = (__bridge EZAudioPlayer *)inRefCon;
    
    //
    // provide the audio received delegate callback
    //
    if (*ioActionFlags & kAudioUnitRenderAction_PostRender)
    {
        if ([player.delegate respondsToSelector:@selector(audioPlayer:readAudio:withBufferSize:withNumberOfChannels:inAudioFile:)])
        {
            UInt32 channels = player.info->clientFormat.mChannelsPerFrame;
            float *buffers[channels];
            for (int i = 0; i < channels; i++)
            {
                buffers[i] = ioData->mBuffers[i].mData;
            }
            [player.delegate audioPlayer:player
                               readAudio:buffers
                          withBufferSize:inNumberFrames
                    withNumberOfChannels:channels
                             inAudioFile:player.audioFile];
        }
    }
    return noErr;
}
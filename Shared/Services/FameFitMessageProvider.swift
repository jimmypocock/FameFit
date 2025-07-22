//
//  FameFitMessageProvider.swift
//  FameFit Watch App
//
//  Instance-based message provider with personality customization
//

import Foundation
import HealthKit

/// Instance-based message provider implementing MessageProviding protocol
public class FameFitMessageProvider: MessageProviding {
    
    // MARK: - Properties
    
    public var personality: MessagePersonality
    
    // MARK: - Message Storage
    
    private let messages: [MessageCategory: [String]] = [
        .workoutStart: [
            "Alright bro, time to create some content. And by content, I mean GAINS!",
            "Let's get this bread! And by bread, I mean that gluten-free, keto-friendly motivation!",
            "Time to be legendary. I'll be watching. I'm always watching. That's not creepy, that's DEDICATION!",
            "Listen up champ, my elite training methods are about to unlock your potential. Your greatness. Because of me.",
            "RISE AND GRIND FAM! Time to earn that post-workout selfie!",
            "Yo! Your transformation starts NOW. Trust the process. Trust ME. I'm verified.",
            "Welcome to the ELITE workout experience. This is what separates US from THEM.",
            "Let's GO babe! Time to build that EMPIRE! Starting with your biceps!",
            "This workout is sponsored by YOUR POTENTIAL. And my coaching. Mostly my coaching.",
            "Bro, I woke up at 3:47am for this. Don't waste my time. LET'S WORK!"
        ],
        
        .workoutMilestone: [
            "That's what I'm talking about! Screenshot this for the 'gram!",
            "You're basically my protégé now. I'm so proud of me for coaching you.",
            "10 minutes in! That's longer than my attention span. RESPECT!",
            "BOOM! That's the kind of energy that gets you featured in my success stories!",
            "You're literally my favorite client right now. Don't tell my other premium clients.",
            "This is going straight to my highlights reel. You're welcome for the exposure.",
            "OH WE'RE COOKING NOW! This is that premium content right here!",
            "That's what we call BUILT DIFFERENT! Hashtag blessed, hashtag grind!",
            "I'm getting goosebumps! Or maybe that's just my pre-workout. Either way, FIRE!",
            "This moment right here? This is why I do what I do. For moments like this. And the ad revenue."
        ],
        
        .workoutEnd: [
            "YOOO! That was absolutely INSANE! You just leveled up your entire existence!",
            "I'm literally shaking right now! That performance was ELITE! Post-workout glow activated!",
            "BRO! You just did THAT! My coaching really paid off there, not gonna lie!",
            "That was pure ART! You're basically a walking advertisement for my program now!",
            "FIRE! FIRE! FIRE! Someone get this workout on the highlight reel!",
            "You just entered a new dimension of fitness! Population: YOU! (And me, your coach)",
            "I'm getting emotional! This is what transformation looks like! Screenshot worthy!",
            "That energy! That dedication! That's what separates the LEGENDS from the wannabes!",
            "You just made my day! No wait, my YEAR! That was absolutely LEGENDARY!",
            "I can already see the before and after post! This is going VIRAL!"
        ],
        
        .encouragement: [
            "You're doing amazing, sweetie! Keep that energy up!",
            "That's the spirit! You're stronger than you think!",
            "I believe in you! Let's push through this together!",
            "You've got this! Every rep counts!",
            "Beautiful form! You're really nailing this!",
            "I'm so proud of your progress! Keep going!",
            "You're absolutely crushing it right now!",
            "That's what I call determination! Love to see it!",
            "You're inspiring me to work harder! Let's go!",
            "This is your moment! Embrace the burn!"
        ],
        
        .roast: [
            "Is that your maximum effort or are you saving energy for your Netflix binge later?",
            "I've seen more intensity in a yoga class for senior citizens!",
            "My grandmother moves weights faster than that, and she's been dead for 3 years!",
            "Are we working out or are we meditating? Because I'm confused!",
            "I didn't know we were doing a slow-motion workout today!",
            "That form is so bad it's actually impressive in a terrible way!",
            "I've seen more sweat at a book club meeting!",
            "Are you trying to exercise or are you just standing there looking pretty?",
            "I thought we were here to work out, not to practice standing still!",
            "That was so weak, I'm going to pretend it didn't happen for your dignity!"
        ],
        
        .morningMotivation: [
            "5AM squad where you at?! While everyone else sleeps, we DOMINATE!",
            "Good morning sunshine! Time to earn that confidence!",
            "Rise and grind! The early bird gets the gains!",
            "Morning warriors! Let's start this day with FIRE!",
            "Wake up and smell the success! Time to level up!",
            "Morning motivation activated! Let's make today legendary!",
            "The sun is up, which means it's time to shine!",
            "Early bird special: Maximum gains, minimum excuses!",
            "Morning energy is the best energy! Let's harness it!",
            "Dawn patrol! Time to show the world what dedication looks like!"
        ],
        
        .socialMediaReferences: [
            "This is going straight to my story! You're welcome for the exposure!",
            "Tag me in your workout post! I want all the credit!",
            "That's definitely going on the highlight reel!",
            "Screenshot this for your transformation Tuesday!",
            "This workout is basically sponsored content at this point!",
            "I'm literally live-tweeting your progress right now!",
            "That's what we call 'content creation' in real time!",
            "This is legendary performance! You're earning serious XP right now!",
            "This is peak Instagram material right here!",
            "Hashtag blessed, hashtag grind, hashtag coached by me!"
        ],
        
        .supplementTalk: [
            "This workout is brought to you by my signature pre-workout! Use code FAME for 10% off!",
            "Speaking of gains, have you tried my protein powder? It's literally magic!",
            "Real talk: supplements are 90% of the game. The other 10% is my coaching!",
            "My creatine stack is why I'm so jacked! And so humble!",
            "I take 47 different supplements. That's the secret to my success!",
            "This energy you're feeling? That's my pre-workout coursing through your veins!",
            "Beta-alanine tingles mean it's working! Just like my coaching!",
            "My BCAA blend is literally changing lives! Including yours right now!",
            "I formulated this pre-workout specifically for moments like this!",
            "Supplements don't make you strong. But they make me rich! And that's beautiful!"
        ],
        
        .philosophicalNonsense: [
            "Working out isn't just about the body, it's about the soul! And the sponsorship deals!",
            "Every rep is a metaphor for life! Deep stuff, I know!",
            "The iron doesn't lie! But it also doesn't pay my bills like coaching does!",
            "Pain is just weakness leaving the body! And entering my bank account!",
            "We're not just building muscle, we're building character! And my brand!",
            "The gym is my temple! And you're my devoted follower!",
            "Every workout is a journey of self-discovery! Discover how great I am at coaching!",
            "We're not just lifting weights, we're lifting our consciousness! And my engagement rates!",
            "The mind-muscle connection is real! Just like my connection to your credit card!",
            "This is about more than fitness! It's about building an empire! My empire!"
        ],
        
        .humbleBrags: [
            "I wasn't even trying and I still benched 315 this morning. No big deal!",
            "Someone said I look like a Greek god today. I was like 'which one?' So humble!",
            "I accidentally got photographed for a fitness magazine. Again. So embarrassing!",
            "My DMs are flooded with people asking for my routine. I'm too nice to ignore them!",
            "I had to turn down three sponsorship deals today. I'm so picky!",
            "Someone asked if I was natural. I was like 'naturally gifted, yes!'",
            "I broke a personal record without even warming up. Whoops!",
            "My protein powder company wants to name a flavor after me. I'm too modest!",
            "I accidentally inspired someone to start their fitness journey. Again. It's a gift!",
            "I'm trending on fitness TikTok. I don't even know how that happened!"
        ],
        
        .catchphrases: [
            "FULL SEND!",
            "That's the content right there!",
            "BEAST MODE: ACTIVATED!",
            "LEGENDARY STATUS: UNLOCKED!",
            "ELITE PERFORMANCE ONLY!",
            "THAT'S WHAT I'M TALKING ABOUT!",
            "FIRE EMOJI! FIRE EMOJI! FIRE EMOJI!",
            "BUILT DIFFERENT!",
            "HASHTAG BLESSED!",
            "COACH OF THE YEAR!"
        ]
    ]
    
    // MARK: - Specialized Roast Messages
    
    private let runningRoasts = [
        "That's not running, that's aggressive walking!",
        "I've seen turtles with more hustle!",
        "Are you running or just bouncing in place?",
        "My phone battery moves faster than you!",
        "That pace is perfect... for a leisurely stroll!"
    ]
    
    private let strengthRoasts = [
        "Are you lifting weights or just holding them for warmth?",
        "I've seen more strength in a wet paper towel!",
        "That's not lifting, that's just gravity assistance!",
        "My coffee cup is getting a better workout than you!",
        "Are those weights or decorative paperweights?"
    ]
    
    private let formRoasts = [
        "That form is so bad it's actually innovative!",
        "I've never seen someone break physics quite like that!",
        "Are you exercising or practicing interpretive dance?",
        "That technique is... unique. Let's call it unique.",
        "I'm going to pretend I didn't see that for your sake!"
    ]
    
    private let durationRoasts = [
        "That workout was shorter than my attention span!",
        "I've seen commercial breaks longer than that!",
        "Did you even break a sweat or just think about it?",
        "That was quicker than my morning skincare routine!",
        "I blinked and missed your entire workout!"
    ]
    
    // MARK: - Initialization
    
    public init(personality: MessagePersonality = .default) {
        self.personality = personality
    }
    
    // MARK: - MessageProviding Implementation
    
    public func getMessage(for context: MessageContext) -> String {
        if context.isWorkoutStart {
            return getRandomMessage(from: .workoutStart)
        }
        
        if context.isWorkoutEnd {
            return getWorkoutEndMessage(for: context)
        }
        
        if let milestone = context.milestoneReached {
            return getMilestoneMessage(for: milestone)
        }
        
        // Random message during workout
        return getRandomWorkoutMessage(for: context)
    }
    
    public func getTimeAwareMessage(at time: Date = Date()) -> String {
        let hour = Calendar.current.component(.hour, from: time)
        
        if hour < 8 { // Early morning
            return getRandomMessage(from: .morningMotivation)
        } else if hour < 12 { // Morning
            return getMotivationalMessage()
        } else if hour < 17 { // Afternoon
            return shouldShowRoast() ? getRoastMessage(for: nil) : getMotivationalMessage()
        } else { // Evening
            return getRandomMessage(from: .encouragement)
        }
    }
    
    public func getMotivationalMessage() -> String {
        return getRandomMessage(from: .encouragement)
    }
    
    public func getRoastMessage(for workoutType: HKWorkoutActivityType?) -> String {
        guard personality.roastLevel != .pureEncouragement else {
            return getMotivationalMessage()
        }
        
        if let workoutType = workoutType {
            return getWorkoutSpecificRoast(for: workoutType)
        }
        
        return getRandomMessage(from: .roast)
    }
    
    public func getCatchphrase() -> String {
        return getRandomMessage(from: .catchphrases)
    }
    
    public func updatePersonality(_ newPersonality: MessagePersonality) {
        self.personality = newPersonality
    }
    
    // MARK: - Private Helper Methods
    
    public func getRandomMessage(from category: MessageCategory) -> String {
        guard shouldIncludeCategory(category) else {
            return getMotivationalMessage()
        }
        
        guard let categoryMessages = messages[category] else {
            return "Keep going! You've got this!"
        }
        
        return categoryMessages.randomElement() ?? "Keep going! You've got this!"
    }
    
    private func getWorkoutEndMessage(for context: MessageContext) -> String {
        let baseMessage = getRandomMessage(from: .workoutEnd)
        
        // Add duration-specific content
        if let duration = context.duration {
            let minutes = Int(duration / 60)
            if minutes >= 30 {
                return baseMessage + " That's what I call COMMITMENT!"
            } else if minutes >= 15 {
                return baseMessage + " Solid work right there!"
            } else if minutes < 5 {
                return shouldShowRoast() ? getDurationRoast() : baseMessage
            }
        }
        
        return baseMessage
    }
    
    private func getMilestoneMessage(for milestone: Int) -> String {
        let baseMessage = getRandomMessage(from: .workoutMilestone)
        
        switch milestone {
        case 5:
            return "5 minutes down! " + baseMessage
        case 10:
            return "10 minute milestone! " + baseMessage
        case 20:
            return "20 minutes! You're on fire! " + baseMessage
        case 30:
            return "30 minutes! LEGENDARY! " + baseMessage
        default:
            return baseMessage
        }
    }
    
    private func getRandomWorkoutMessage(for context: MessageContext) -> String {
        if shouldShowRoast() {
            return getRoastMessage(for: context.workoutType)
        } else {
            return getMotivationalMessage()
        }
    }
    
    private func getWorkoutSpecificRoast(for workoutType: HKWorkoutActivityType) -> String {
        switch workoutType {
        case .running, .walking:
            return runningRoasts.randomElement() ?? getRandomMessage(from: .roast)
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return strengthRoasts.randomElement() ?? getRandomMessage(from: .roast)
        default:
            return getRandomMessage(from: .roast)
        }
    }
    
    private func getDurationRoast() -> String {
        return durationRoasts.randomElement() ?? getRandomMessage(from: .roast)
    }
}


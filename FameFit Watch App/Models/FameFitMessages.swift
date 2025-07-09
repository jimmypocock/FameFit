//
//  FameFitMessages.swift
//  FameFit Watch App
//
//  Created for FameFit App - Your Personal Fitness Influencer
//

import Foundation

struct FameFitMessages {
    enum MessageCategory {
        case workoutStart
        case workoutMilestone
        case workoutEnd
        case missedWorkout
        case achievement
        case encouragement
        case roast
        case morningMotivation
        case socialMediaReferences
        case supplementTalk
        case philosophicalNonsense
        case humbleBrags
        case catchphrases
    }

    static let messages: [MessageCategory: [String]] = [
        .workoutStart: [
            "Alright bro, time to create some content. And by content, I mean GAINS!",
            "Let's get this bread! And by bread, I mean that gluten-free, keto-friendly motivation!",
            "Time to be legendary. I'll be watching. I'm always watching. That's not creepy, that's DEDICATION!",
            "Listen up champ, my 2.3 million followers are about to witness greatness. Your greatness. Because of me.",
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
            "You're literally my favorite client right now. Don't tell my other 2.3 million followers.",
            "This is going straight to my highlights reel. You're welcome for the exposure.",
            "OH WE'RE COOKING NOW! This is that premium content right here!",
            "That's what we call BUILT DIFFERENT! Hashtag blessed, hashtag grind!",
            "I'm getting goosebumps! Or maybe that's just my pre-workout. Either way, FIRE!",
            "You just unlocked a new level! I'll mention you in my podcast. Maybe."
        ],

        .workoutEnd: [
            "And THAT'S how you build a brand! I mean body. I mean both!",
            "Don't forget to tag me in your transformation posts. #CoachedByTheBest",
            "You crushed it! Almost as hard as I crush my 4am workouts. Almost.",
            "Session complete! Now go tell everyone about your amazing coach. That's me, BTW.",
            "BOOM! Another success story for my portfolio. You did okay too.",
            "That's a WRAP! Time to update your bio: 'Trained by a fitness influencer'",
            "Killed it! This is why they pay me the big bucks. You don't pay me? Weird.",
            "And scene! That was beautiful. I might cry. These are gains tears.",
            "You're officially part of the ELITE now. Welcome to the 1% club!",
            "That's what champions do! I should know, I've coached like... so many."
        ],

        .missedWorkout: [
            "Bro... my 2.3 million followers are asking about you. Don't embarrass me.",
            "Your rest day is having rest days. That's not the MINDSET we discussed!",
            "I didn't wake up at 4am to have clients who sleep in. Just saying.",
            "Even my supplement stack is disappointed in you right now.",
            "You're breaking my heart. And my perfect client success rate.",
            "This isn't the ENERGY we need for your transformation Tuesday post!",
            "I've been getting DMs asking if I lost a client. Is that what you want?",
            "Your muscles are filing a missing person report. I'm listed as a witness.",
            "My engagement rate drops when my clients don't show up. Think about that.",
            "Remember what I always say: 'Consistency is key.' I literally trademarked that."
        ],

        .achievement: [
            "YOOO! You just earned 'Client of the Month'! I'm adding this to my website!",
            "Achievement unlocked: BEAST MODE! I'm so good at my job it's scary.",
            "Welcome to my ELITE INNER CIRCLE! There's like 50,000 of you but still!",
            "You're now a certified SUCCESS STORY! I'll need you to sign a testimonial.",
            "LEGENDARY STATUS ACHIEVED! This is going in my course materials!",
            "You just went VIRAL in my heart! And my client spreadsheet!",
            "That's TRANSFORMATION TUESDAY material right there! I'm a genius!",
            "You're officially BUILT DIFFERENT! It's the coaching, obviously.",
            "NEW PERSONAL RECORD! I'm increasing my rates. Not for you though. Maybe.",
            "You just became a CASE STUDY! Chapter 7 in my upcoming book!"
        ],

        .encouragement: [
            "Remember what I always say: 'Pain is just weakness leaving the body.' I invented that.",
            "You're not tired, you're just building CHARACTER! And content!",
            "This is where LEGENDS are made! In this exact heart rate zone!",
            "Trust the process! It's scientifically proven. I have a YouTube video about it.",
            "You're doing amazing sweetie! Your form needs work but the EFFORT is there!",
            "Channel that INNER CHAMPION! I see it in you. I see it in all my clients.",
            "This is your MOMENT! Make it count! Make ME proud!",
            "Feel that burn? That's SUCCESS cooking! Recipe by yours truly.",
            "You've got that WINNER'S MINDSET! Available in my $497 course!",
            "Keep pushing! My reputation depends on it! I mean... you got this!"
        ],

        .roast: [
            "That pace wouldn't even trend on TikTok.",
            "I've seen more intensity in my morning meditation.",
            "Your heart rate is giving 'unboxing video' energy.",
            "That effort level won't even get you on my story highlights.",
            "My grandma has more followers AND a faster mile time.",
            "You're making my other clients look like olympians. They're not.",
            "That's the energy of someone who skips my motivational posts.",
            "I can't make content with THIS. What am I supposed to post?",
            "Your workout intensity is set to 'influencer apology video'.",
            "Even my ring light is working harder than you right now."
        ],

        .morningMotivation: [
            "RISE AND GRIND! It's 5AM somewhere! Actually it's 5AM here. I'm up. Why aren't you?",
            "Morning CHAMPION! Time to earn that breakfast! Protein shake, obviously.",
            "The early bird gets the GAINS! I should know, I've been up since 3:47am!",
            "Good morning SUPERSTAR! Let's make today LEGENDARY! I already posted about it.",
            "AM CREW WHERE YOU AT?! Time to separate yourself from the 99%!"
        ],

        .socialMediaReferences: [
            "This is the kind of dedication that gets you VERIFIED!",
            "Your story views are gonna EXPLODE after this workout!",
            "Content creation starts with SWEAT CREATION! That's my motto!",
            "This workout brought to you by that INFLUENCER MINDSET!",
            "Going viral starts with going HARD! Facts!"
        ],

        .supplementTalk: [
            "Hope you took your pre-workout! I took three scoops. Don't do that.",
            "This is why I partner with supplement companies! Pure performance!",
            "Feeling that PUMP? That's not just the workout, that's OPTIMAL NUTRITION!",
            "Remember: supplements are 20% of results. My coaching is the other 90%!",
            "Post-workout window opening in 3... 2... 1... PROTEIN TIME!"
        ],

        .philosophicalNonsense: [
            "Life isn't about the destination, it's about the GAINS along the way.",
            "You're not just building muscle, you're building CHARACTER. Deep, right?",
            "Every rep is a metaphor for life. I just blew your mind.",
            "Sweat is just your fat crying. I came up with that. Don't Google it.",
            "The gym is a meditation chamber. Your muscles are the monks. Think about it."
        ],

        .humbleBrags: [
            "Not to brag but my client retention rate is basically 100%. You're proof!",
            "I turned down 5 brand deals this morning to be here with you. Dedication!",
            "My other clients include CEOs, athletes, and a few celebrities I can't name.",
            "I was featured in Men's Health last month. Page 97. Small feature. No big deal.",
            "Just got verified on my third platform. But this workout is about YOU!"
        ],

        .catchphrases: [
            "LET'S GOOOOO!",
            "BUILT DIFFERENT!",
            "NO DAYS OFF!",
            "TRUST THE PROCESS!",
            "STAY HARD!",
            "ELITE MINDSET!",
            "DIFFERENT BREED!",
            "ON A MISSION!",
            "LOCKED IN!",
            "DIALED IN!"
        ]
    ]

    static func getMessage(for category: MessageCategory) -> String {
        return messages[category]?.randomElement() ?? "Stay hard bro! 💪"
    }

    static func getTimeAwareMessage() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 4..<7:
            return getMessage(for: .morningMotivation)
        case 7..<12:
            return messages[.catchphrases]?.randomElement() ?? "Morning grind time!"
        case 12..<17:
            return "Lunch break workout? That's that CEO MINDSET! Love it!"
        case 17..<21:
            return "Evening sessions hit different! This is PRIME TIME baby!"
        case 21..<24:
            return "Late night grind! While they sleep, WE WORK! #DifferentBreed"
        default:
            return "3AM workout? You're officially PSYCHO! I LOVE IT! Same energy!"
        }
    }

    static func getWorkoutSpecificMessage(workoutType: String, duration: TimeInterval) -> String {
        switch workoutType.lowercased() {
        case "run":
            if duration < 300 {
                return "Quick sprint session! Fast like my Instagram story views!"
            } else if duration < 1_200 {
                return "Solid run bro! Your cardio is almost as good as my content!"
            } else {
                return "MARATHON MINDSET! You're going the distance! Like my YouTube videos!"
            }
        case "bike":
            if duration < 600 {
                return "Quick spin! Your legs are gonna be CONTENT tomorrow!"
            } else {
                return "Tour de GAINS! You're crushing it like my engagement rate!"
            }
        case "walk":
            return "Walking is CARDIO too! Every step is a step toward GREATNESS!"
        default:
            return getMessage(for: .encouragement)
        }
    }

    static let runningRoasts = [
        "You're getting lapped by my morning jog pace. And I was vlogging!",
        "That's not running, that's aggressively podcasting!",
        "Your pace is giving 'Instagram Reel transition' energy!",
        "I've seen faster movement in my DM responses!",
        "Your marathon pace is my warm-up walk. Just saying!"
    ]

    static let strengthRoasts = [
        "That weight wouldn't even make it into my pump video!",
        "Are those reps or are you posing for thumbnails?",
        "I've lifted heavier cameras for my content!",
        "Your PR is my warm-up. Your warm-up is my rest day!",
        "That form needs more work than my video editing!"
    ]

    static let formRoasts = [
        "That form wouldn't even get likes on fitness TikTok!",
        "Your technique needs a collab with proper coaching. I'm available!",
        "Even my ring light has better posture than that!",
        "That's not how I demonstrated it in my tutorial video!",
        "Your form is like my first YouTube videos. We don't talk about those!"
    ]

    static let durationRoasts = [
        "Your workout was shorter than my intro sequence!",
        "That session wouldn't even fill an Instagram story!",
        "I've done longer podcasts intros than that workout!",
        "Your rest periods are longer than my YouTube ads!",
        "That workout duration is giving 'free trial' energy!"
    ]
}

//
//  HKWorkoutActivityType+Extensions.swift
//  FameFit
//
//  Unified extension for HKWorkoutActivityType conversions and mappings
//

import HealthKit

extension HKWorkoutActivityType {
    
    // MARK: - Display Name
    /// Human-readable display name for the workout type
    var displayName: String {
        switch self {
        case .americanFootball:
            return "American Football"
        case .archery:
            return "Archery"
        case .australianFootball:
            return "Australian Football"
        case .badminton:
            return "Badminton"
        case .barre:
            return "Barre"
        case .baseball:
            return "Baseball"
        case .basketball:
            return "Basketball"
        case .bowling:
            return "Bowling"
        case .boxing:
            return "Boxing"
        case .cardioDance:
            return "Cardio Dance"
        case .climbing:
            return "Climbing"
        case .cooldown:
            return "Cooldown"
        case .coreTraining:
            return "Core Training"
        case .cricket:
            return "Cricket"
        case .crossCountrySkiing:
            return "Cross Country Skiing"
        case .crossTraining:
            return "Cross Training"
        case .curling:
            return "Curling"
        case .cycling:
            return "Cycling"
        case .dance:
            return "Dance"
        case .danceInspiredTraining:
            return "Dance Training"
        case .discSports:
            return "Disc Sports"
        case .downhillSkiing:
            return "Downhill Skiing"
        case .elliptical:
            return "Elliptical"
        case .equestrianSports:
            return "Equestrian"
        case .fencing:
            return "Fencing"
        case .fishing:
            return "Fishing"
        case .fitnessGaming:
            return "Fitness Gaming"
        case .flexibility:
            return "Flexibility"
        case .functionalStrengthTraining:
            return "Functional Strength"
        case .golf:
            return "Golf"
        case .gymnastics:
            return "Gymnastics"
        case .handCycling:
            return "Hand Cycling"
        case .handball:
            return "Handball"
        case .highIntensityIntervalTraining:
            return "HIIT"
        case .hiking:
            return "Hiking"
        case .hockey:
            return "Hockey"
        case .hunting:
            return "Hunting"
        case .jumpRope:
            return "Jump Rope"
        case .kickboxing:
            return "Kickboxing"
        case .lacrosse:
            return "Lacrosse"
        case .martialArts:
            return "Martial Arts"
        case .mindAndBody:
            return "Mind and Body"
        case .mixedCardio:
            return "Mixed Cardio"
        case .mixedMetabolicCardioTraining:
            return "Mixed Metabolic Cardio"
        case .other:
            return "Other"
        case .paddleSports:
            return "Paddle Sports"
        case .pickleball:
            return "Pickleball"
        case .pilates:
            return "Pilates"
        case .play:
            return "Play"
        case .preparationAndRecovery:
            return "Recovery"
        case .racquetball:
            return "Racquetball"
        case .rowing:
            return "Rowing"
        case .rugby:
            return "Rugby"
        case .running:
            return "Running"
        case .sailing:
            return "Sailing"
        case .skatingSports:
            return "Skating"
        case .snowboarding:
            return "Snowboarding"
        case .snowSports:
            return "Snow Sports"
        case .soccer:
            return "Soccer"
        case .socialDance:
            return "Social Dance"
        case .softball:
            return "Softball"
        case .squash:
            return "Squash"
        case .stairClimbing:
            return "Stair Climbing"
        case .stairs:
            return "Stairs"
        case .stepTraining:
            return "Step Training"
        case .surfingSports:
            return "Surfing"
        case .swimming:
            return "Swimming"
        case .swimBikeRun:
            return "Triathlon"
        case .tableTennis:
            return "Table Tennis"
        case .taiChi:
            return "Tai Chi"
        case .tennis:
            return "Tennis"
        case .trackAndField:
            return "Track and Field"
        case .traditionalStrengthTraining:
            return "Strength Training"
        case .transition:
            return "Transition"
        case .underwaterDiving:
            return "Underwater Diving"
        case .volleyball:
            return "Volleyball"
        case .walking:
            return "Walking"
        case .waterFitness:
            return "Water Fitness"
        case .waterPolo:
            return "Water Polo"
        case .waterSports:
            return "Water Sports"
        case .wheelchairRunPace:
            return "Wheelchair Run"
        case .wheelchairWalkPace:
            return "Wheelchair Walk"
        case .wrestling:
            return "Wrestling"
        case .yoga:
            return "Yoga"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Storage Key
    /// Snake-case string key for storage/serialization
    var storageKey: String {
        switch self {
        case .americanFootball:
            return "american_football"
        case .archery:
            return "archery"
        case .australianFootball:
            return "australian_football"
        case .badminton:
            return "badminton"
        case .barre:
            return "barre"
        case .baseball:
            return "baseball"
        case .basketball:
            return "basketball"
        case .bowling:
            return "bowling"
        case .boxing:
            return "boxing"
        case .cardioDance:
            return "cardio_dance"
        case .climbing:
            return "climbing"
        case .cooldown:
            return "cooldown"
        case .coreTraining:
            return "core_training"
        case .cricket:
            return "cricket"
        case .crossCountrySkiing:
            return "cross_country_skiing"
        case .crossTraining:
            return "cross_training"
        case .curling:
            return "curling"
        case .cycling:
            return "cycling"
        case .dance:
            return "dance"
        case .danceInspiredTraining:
            return "dance_inspired_training"
        case .discSports:
            return "disc_sports"
        case .downhillSkiing:
            return "downhill_skiing"
        case .elliptical:
            return "elliptical"
        case .equestrianSports:
            return "equestrian_sports"
        case .fencing:
            return "fencing"
        case .fishing:
            return "fishing"
        case .fitnessGaming:
            return "fitness_gaming"
        case .flexibility:
            return "flexibility"
        case .functionalStrengthTraining:
            return "functional_strength_training"
        case .golf:
            return "golf"
        case .gymnastics:
            return "gymnastics"
        case .handCycling:
            return "hand_cycling"
        case .handball:
            return "handball"
        case .highIntensityIntervalTraining:
            return "high_intensity_interval_training"
        case .hiking:
            return "hiking"
        case .hockey:
            return "hockey"
        case .hunting:
            return "hunting"
        case .jumpRope:
            return "jump_rope"
        case .kickboxing:
            return "kickboxing"
        case .lacrosse:
            return "lacrosse"
        case .martialArts:
            return "martial_arts"
        case .mindAndBody:
            return "mind_and_body"
        case .mixedCardio:
            return "mixed_cardio"
        case .mixedMetabolicCardioTraining:
            return "mixed_metabolic_cardio_training"
        case .other:
            return "other"
        case .paddleSports:
            return "paddle_sports"
        case .pickleball:
            return "pickleball"
        case .pilates:
            return "pilates"
        case .play:
            return "play"
        case .preparationAndRecovery:
            return "preparation_and_recovery"
        case .racquetball:
            return "racquetball"
        case .rowing:
            return "rowing"
        case .rugby:
            return "rugby"
        case .running:
            return "running"
        case .sailing:
            return "sailing"
        case .skatingSports:
            return "skating_sports"
        case .snowboarding:
            return "snowboarding"
        case .snowSports:
            return "snow_sports"
        case .soccer:
            return "soccer"
        case .socialDance:
            return "social_dance"
        case .softball:
            return "softball"
        case .squash:
            return "squash"
        case .stairClimbing:
            return "stair_climbing"
        case .stairs:
            return "stairs"
        case .stepTraining:
            return "step_training"
        case .surfingSports:
            return "surfing_sports"
        case .swimming:
            return "swimming"
        case .swimBikeRun:
            return "swim_bike_run"
        case .tableTennis:
            return "table_tennis"
        case .taiChi:
            return "tai_chi"
        case .tennis:
            return "tennis"
        case .trackAndField:
            return "track_and_field"
        case .traditionalStrengthTraining:
            return "traditional_strength_training"
        case .transition:
            return "transition"
        case .underwaterDiving:
            return "underwater_diving"
        case .volleyball:
            return "volleyball"
        case .walking:
            return "walking"
        case .waterFitness:
            return "water_fitness"
        case .waterPolo:
            return "water_polo"
        case .waterSports:
            return "water_sports"
        case .wheelchairRunPace:
            return "wheelchair_run_pace"
        case .wheelchairWalkPace:
            return "wheelchair_walk_pace"
        case .wrestling:
            return "wrestling"
        case .yoga:
            return "yoga"
        @unknown default:
            return "unknown"
        }
    }
    
    // MARK: - From Storage Key
    /// Initialize from storage key string
    static func from(storageKey: String) -> HKWorkoutActivityType? {
        switch storageKey {
        case "american_football":
            return .americanFootball
        case "archery":
            return .archery
        case "australian_football":
            return .australianFootball
        case "badminton":
            return .badminton
        case "barre":
            return .barre
        case "baseball":
            return .baseball
        case "basketball":
            return .basketball
        case "bowling":
            return .bowling
        case "boxing":
            return .boxing
        case "cardio_dance":
            return .cardioDance
        case "climbing":
            return .climbing
        case "cooldown":
            return .cooldown
        case "core_training":
            return .coreTraining
        case "cricket":
            return .cricket
        case "cross_country_skiing":
            return .crossCountrySkiing
        case "cross_training":
            return .crossTraining
        case "curling":
            return .curling
        case "cycling":
            return .cycling
        case "disc_sports":
            return .discSports
        case "downhill_skiing":
            return .downhillSkiing
        case "elliptical":
            return .elliptical
        case "equestrian_sports":
            return .equestrianSports
        case "fencing":
            return .fencing
        case "fishing":
            return .fishing
        case "fitness_gaming":
            return .fitnessGaming
        case "flexibility":
            return .flexibility
        case "functional_strength_training":
            return .functionalStrengthTraining
        case "golf":
            return .golf
        case "gymnastics":
            return .gymnastics
        case "hand_cycling":
            return .handCycling
        case "handball":
            return .handball
        case "high_intensity_interval_training":
            return .highIntensityIntervalTraining
        case "hiking":
            return .hiking
        case "hockey":
            return .hockey
        case "hunting":
            return .hunting
        case "jump_rope":
            return .jumpRope
        case "kickboxing":
            return .kickboxing
        case "lacrosse":
            return .lacrosse
        case "martial_arts":
            return .martialArts
        case "mind_and_body":
            return .mindAndBody
        case "mixed_cardio":
            return .mixedCardio
        case "other":
            return .other
        case "paddle_sports":
            return .paddleSports
        case "pickleball":
            return .pickleball
        case "pilates":
            return .pilates
        case "play":
            return .play
        case "preparation_and_recovery":
            return .preparationAndRecovery
        case "racquetball":
            return .racquetball
        case "rowing":
            return .rowing
        case "rugby":
            return .rugby
        case "running":
            return .running
        case "sailing":
            return .sailing
        case "skating_sports":
            return .skatingSports
        case "snowboarding":
            return .snowboarding
        case "snow_sports":
            return .snowSports
        case "soccer":
            return .soccer
        case "social_dance":
            return .socialDance
        case "softball":
            return .softball
        case "squash":
            return .squash
        case "stair_climbing":
            return .stairClimbing
        case "stairs":
            return .stairs
        case "step_training":
            return .stepTraining
        case "surfing_sports":
            return .surfingSports
        case "swimming":
            return .swimming
        case "swim_bike_run":
            return .swimBikeRun
        case "table_tennis":
            return .tableTennis
        case "tai_chi":
            return .taiChi
        case "tennis":
            return .tennis
        case "track_and_field":
            return .trackAndField
        case "traditional_strength_training":
            return .traditionalStrengthTraining
        case "transition":
            return .transition
        case "underwater_diving":
            return .underwaterDiving
        case "volleyball":
            return .volleyball
        case "walking":
            return .walking
        case "water_fitness":
            return .waterFitness
        case "water_polo":
            return .waterPolo
        case "water_sports":
            return .waterSports
        case "wheelchair_run_pace":
            return .wheelchairRunPace
        case "wheelchair_walk_pace":
            return .wheelchairWalkPace
        case "wrestling":
            return .wrestling
        case "yoga":
            return .yoga
            
        // Handle deprecated cases - map to modern equivalents
        case "dance":
            return .cardioDance
        case "dance_inspired_training":
            return .barre
        case "mixed_metabolic_cardio_training":
            return .highIntensityIntervalTraining
            
        default:
            return nil
        }
    }
    
    // MARK: - Icon Name
    /// SF Symbol name for the workout type
    var iconName: String {
        switch self {
        case .americanFootball:
            return "figure.american.football"
        case .archery:
            return "figure.archery"
        case .australianFootball:
            return "figure.australian.football"
        case .badminton, .tennis, .tableTennis, .racquetball, .squash, .pickleball:
            return "figure.tennis"
        case .barre:
            return "figure.barre"
        case .baseball, .softball:
            return "figure.baseball"
        case .basketball:
            return "figure.basketball"
        case .bowling:
            return "figure.bowling"
        case .boxing, .kickboxing, .martialArts:
            return "figure.martial.arts"
        case .cardioDance, .dance, .socialDance:
            return "figure.dance"
        case .climbing:
            return "figure.climbing"
        case .cooldown:
            return "figure.cooldown"
        case .coreTraining:
            return "figure.core.training"
        case .cricket:
            return "figure.cricket"
        case .crossCountrySkiing, .downhillSkiing, .snowboarding, .snowSports:
            return "figure.snowboarding"
        case .crossTraining, .functionalStrengthTraining, .traditionalStrengthTraining:
            return "figure.strengthtraining.traditional"
        case .curling:
            return "figure.curling"
        case .cycling:
            return "bicycle"
        case .danceInspiredTraining:
            return "figure.dance"
        case .discSports:
            return "figure.disc.sports"
        case .elliptical:
            return "figure.elliptical"
        case .equestrianSports:
            return "figure.equestrian.sports"
        case .fencing:
            return "figure.fencing"
        case .fishing:
            return "figure.fishing"
        case .fitnessGaming:
            return "gamecontroller"
        case .flexibility:
            return "figure.flexibility"
        case .golf:
            return "figure.golf"
        case .gymnastics:
            return "figure.gymnastics"
        case .handCycling:
            return "figure.hand.cycling"
        case .handball:
            return "figure.handball"
        case .highIntensityIntervalTraining:
            return "figure.highintensity.intervaltraining"
        case .hiking:
            return "figure.hiking"
        case .hockey:
            return "figure.hockey"
        case .hunting:
            return "figure.hunting"
        case .jumpRope:
            return "figure.jumprope"
        case .lacrosse:
            return "figure.lacrosse"
        case .mindAndBody:
            return "figure.mind.and.body"
        case .mixedCardio, .mixedMetabolicCardioTraining:
            return "figure.mixed.cardio"
        case .other:
            return "figure.wave"
        case .paddleSports:
            return "figure.outdoor.cycle"
        case .pilates:
            return "figure.pilates"
        case .play:
            return "figure.play"
        case .preparationAndRecovery:
            return "figure.strengthtraining.functional"
        case .rowing:
            return "figure.rowing"
        case .rugby:
            return "figure.rugby"
        case .running:
            return "figure.run"
        case .sailing:
            return "sailboat"
        case .skatingSports:
            return "figure.skating"
        case .soccer:
            return "figure.soccer"
        case .stairClimbing, .stairs:
            return "figure.stairs"
        case .stepTraining:
            return "figure.step.training"
        case .surfingSports:
            return "figure.surfing"
        case .swimming:
            return "figure.pool.swim"
        case .swimBikeRun:
            return "figure.open.water.swim"
        case .taiChi:
            return "figure.taichi"
        case .trackAndField:
            return "figure.track.and.field"
        case .transition:
            return "arrow.triangle.2.circlepath"
        case .underwaterDiving:
            return "figure.water.fitness"
        case .volleyball:
            return "figure.volleyball"
        case .walking:
            return "figure.walk"
        case .waterFitness, .waterPolo, .waterSports:
            return "figure.water.fitness"
        case .wheelchairRunPace, .wheelchairWalkPace:
            return "figure.roll"
        case .wrestling:
            return "figure.wrestling"
        case .yoga:
            return "figure.yoga"
        @unknown default:
            return "questionmark.circle"
        }
    }
}
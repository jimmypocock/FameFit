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

    // MARK: - From Display Name
    
    /// Initialize from display name string
    static func fromDisplayName(_ displayName: String) -> HKWorkoutActivityType? {
        // Use a map to reverse lookup display names
        let displayNameMap: [String: HKWorkoutActivityType] = [
            "American Football": .americanFootball,
            "Archery": .archery,
            "Australian Football": .australianFootball,
            "Badminton": .badminton,
            "Barre": .barre,
            "Baseball": .baseball,
            "Basketball": .basketball,
            "Bowling": .bowling,
            "Boxing": .boxing,
            "Cardio Dance": .cardioDance,
            "Climbing": .climbing,
            "Cooldown": .cooldown,
            "Core Training": .coreTraining,
            "Cricket": .cricket,
            "Cross Country Skiing": .crossCountrySkiing,
            "Cross Training": .crossTraining,
            "Curling": .curling,
            "Cycling": .cycling,
            "Dance": .dance,
            "Dance Training": .danceInspiredTraining,
            "Disc Sports": .discSports,
            "Downhill Skiing": .downhillSkiing,
            "Elliptical": .elliptical,
            "Equestrian": .equestrianSports,
            "Fencing": .fencing,
            "Fishing": .fishing,
            "Fitness Gaming": .fitnessGaming,
            "Flexibility": .flexibility,
            "Functional Strength": .functionalStrengthTraining,
            "Golf": .golf,
            "Gymnastics": .gymnastics,
            "Hand Cycling": .handCycling,
            "Handball": .handball,
            "HIIT": .highIntensityIntervalTraining,
            "Hiking": .hiking,
            "Hockey": .hockey,
            "Hunting": .hunting,
            "Jump Rope": .jumpRope,
            "Kickboxing": .kickboxing,
            "Lacrosse": .lacrosse,
            "Martial Arts": .martialArts,
            "Mind and Body": .mindAndBody,
            "Mixed Cardio": .mixedCardio,
            "Mixed Metabolic Cardio": .mixedMetabolicCardioTraining,
            "Other": .other,
            "Paddle Sports": .paddleSports,
            "Pickleball": .pickleball,
            "Pilates": .pilates,
            "Play": .play,
            "Recovery": .preparationAndRecovery,
            "Racquetball": .racquetball,
            "Rowing": .rowing,
            "Rugby": .rugby,
            "Running": .running,
            "Sailing": .sailing,
            "Skating": .skatingSports,
            "Snowboarding": .snowboarding,
            "Snow Sports": .snowSports,
            "Soccer": .soccer,
            "Social Dance": .socialDance,
            "Softball": .softball,
            "Squash": .squash,
            "Stair Climbing": .stairClimbing,
            "Stairs": .stairs,
            "Step Training": .stepTraining,
            "Surfing": .surfingSports,
            "Swimming": .swimming,
            "Triathlon": .swimBikeRun,
            "Table Tennis": .tableTennis,
            "Tai Chi": .taiChi,
            "Tennis": .tennis,
            "Track and Field": .trackAndField,
            "Strength Training": .traditionalStrengthTraining,
            "Transition": .transition,
            "Underwater Diving": .underwaterDiving,
            "Volleyball": .volleyball,
            "Walking": .walking,
            "Water Fitness": .waterFitness,
            "Water Polo": .waterPolo,
            "Water Sports": .waterSports,
            "Wheelchair Run": .wheelchairRunPace,
            "Wheelchair Walk": .wheelchairWalkPace,
            "Wrestling": .wrestling,
            "Yoga": .yoga
        ]
        return displayNameMap[displayName]
    }

    // MARK: - From Storage Key

    /// Initialize from storage key string
    static func from(storageKey: String) -> HKWorkoutActivityType? {
        switch storageKey {
        case "american_football":
            .americanFootball
        case "archery":
            .archery
        case "australian_football":
            .australianFootball
        case "badminton":
            .badminton
        case "barre":
            .barre
        case "baseball":
            .baseball
        case "basketball":
            .basketball
        case "bowling":
            .bowling
        case "boxing":
            .boxing
        case "cardio_dance":
            .cardioDance
        case "climbing":
            .climbing
        case "cooldown":
            .cooldown
        case "core_training":
            .coreTraining
        case "cricket":
            .cricket
        case "cross_country_skiing":
            .crossCountrySkiing
        case "cross_training":
            .crossTraining
        case "curling":
            .curling
        case "cycling":
            .cycling
        case "disc_sports":
            .discSports
        case "downhill_skiing":
            .downhillSkiing
        case "elliptical":
            .elliptical
        case "equestrian_sports":
            .equestrianSports
        case "fencing":
            .fencing
        case "fishing":
            .fishing
        case "fitness_gaming":
            .fitnessGaming
        case "flexibility":
            .flexibility
        case "functional_strength_training":
            .functionalStrengthTraining
        case "golf":
            .golf
        case "gymnastics":
            .gymnastics
        case "hand_cycling":
            .handCycling
        case "handball":
            .handball
        case "high_intensity_interval_training":
            .highIntensityIntervalTraining
        case "hiking":
            .hiking
        case "hockey":
            .hockey
        case "hunting":
            .hunting
        case "jump_rope":
            .jumpRope
        case "kickboxing":
            .kickboxing
        case "lacrosse":
            .lacrosse
        case "martial_arts":
            .martialArts
        case "mind_and_body":
            .mindAndBody
        case "mixed_cardio":
            .mixedCardio
        case "other":
            .other
        case "paddle_sports":
            .paddleSports
        case "pickleball":
            .pickleball
        case "pilates":
            .pilates
        case "play":
            .play
        case "preparation_and_recovery":
            .preparationAndRecovery
        case "racquetball":
            .racquetball
        case "rowing":
            .rowing
        case "rugby":
            .rugby
        case "running":
            .running
        case "sailing":
            .sailing
        case "skating_sports":
            .skatingSports
        case "snowboarding":
            .snowboarding
        case "snow_sports":
            .snowSports
        case "soccer":
            .soccer
        case "social_dance":
            .socialDance
        case "softball":
            .softball
        case "squash":
            .squash
        case "stair_climbing":
            .stairClimbing
        case "stairs":
            .stairs
        case "step_training":
            .stepTraining
        case "surfing_sports":
            .surfingSports
        case "swimming":
            .swimming
        case "swim_bike_run":
            .swimBikeRun
        case "table_tennis":
            .tableTennis
        case "tai_chi":
            .taiChi
        case "tennis":
            .tennis
        case "track_and_field":
            .trackAndField
        case "traditional_strength_training":
            .traditionalStrengthTraining
        case "transition":
            .transition
        case "underwater_diving":
            .underwaterDiving
        case "volleyball":
            .volleyball
        case "walking":
            .walking
        case "water_fitness":
            .waterFitness
        case "water_polo":
            .waterPolo
        case "water_sports":
            .waterSports
        case "wheelchair_run_pace":
            .wheelchairRunPace
        case "wheelchair_walk_pace":
            .wheelchairWalkPace
        case "wrestling":
            .wrestling
        case "yoga":
            .yoga
        // Handle deprecated cases - map to modern equivalents
        case "dance":
            .cardioDance
        case "dance_inspired_training":
            .barre
        case "mixed_metabolic_cardio_training":
            .highIntensityIntervalTraining
        default:
            nil
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

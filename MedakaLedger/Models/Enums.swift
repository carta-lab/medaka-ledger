import Foundation

// ARCHITECTURE.md 3.1。保存は rawValue の文字列で行う。表示名は Enums+Label.swift。

enum TankKind: String, CaseIterable, Sendable { case nvBox, toroBune, styrofoam, plaBune, waterLilyPot, aquarium, cup, other }
enum Placement: String, CaseIterable, Sendable { case outdoor, indoor }
enum GrowthStage: String, CaseIterable, Sendable { case hatchling, fry, young, adult }   // 針子、稚魚、若魚、成魚
enum CohortStatus: String, CaseIterable, Sendable { case active, soldOut, merged, lost, archived }
enum CohortEventKind: String, CaseIterable, Sendable { case created, move, split, merge, countChange, stageChange, statusChange, note }
enum CountChangeReason: String, CaseIterable, Sendable { case death, jumpedOut, givenAway, recount, other }
enum EggBatchStatus: String, CaseIterable, Sendable { case incubating, hatched, discarded }
enum CullDestination: String, CaseIterable, Sendable { case feed, cheapSale, separateTank, dispose }   // 放流は用意しない
enum SaleUnit: String, CaseIterable, Sendable { case fish, pair, trio, eggs, fryBundle }
enum SaleChannel: String, CaseIterable, Sendable { case yahooAuction, ownShop, event, consignment, direct, other }
enum SaleStatus: String, CaseIterable, Sendable { case listed, sold, shipped, cancelled }
enum MaintenanceKind: String, CaseIterable, Sendable { case waterChange, topUp, cleaning, medication, temperature, other }

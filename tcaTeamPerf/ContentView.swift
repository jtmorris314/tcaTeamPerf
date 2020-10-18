//
//  ContentView.swift
//  tcaTeamPerf
//
//  Created by Jim Morris on 10/16/20.
//  Copyright © 2020 Jim Morris. All rights reserved.
//

import SwiftUI
import ComposableArchitecture

// Skeleton State and Views of app
//
// State:
//   Teams -> Games -> Videos
//     |
//     -----> Members
//
// ViewModels:
//   TeamVideoFeature (scope: teams)
//    - Team List of Games-Videos (scope: teams)
//      - Games-Videos (scope: games)
//        - Game-Videos (scope: game)
//          - Videos (scope: videos)
//            - Video (scope: video)
//    - Game-Videos Detail View (scope: game)
// *    - Video (scope: video)
//      - Timeline (scope: game)
//        - Edit Trimmer (scope: video)
//      - Videos List (scope: game)
//   Teams List (scope: all)
//    - Team (scope: team)
//      - Members List (scope: members)
//        - Member (scope: member)
//   Recording (scope: game)
//   Phone Sync (scope: game)
//   Remote Marking (scope: game)
//   Profile View (scope: teams)
//
// * Only ViewModel with local state modeled.
//   One entity's local state Double variable changed every 30 ms
//

var printOn: Bool = false

struct AppState: Equatable {
    var masterTime: Double = .zero
    var timerOn: Bool = false
    var currentTeamId: String = "t\(0)"
    var currentGameId: String = "g\(0)"
    var currentVideoId: String = "v\(0)"
    var currentMemberId: String = "m\(0)"
    var teams =
        IdentifiedArrayOf([GenericEntity(id: "t\(0)",
                                         name: "t\(0)",
                                         array1: IdentifiedArrayOf([GenericEntity(id: "m\(0)")]),
                                         array2: IdentifiedArrayOf([GenericEntity(id: "g\(0)",
                                                                                  array1: IdentifiedArrayOf([GenericEntity(id: "v\(0)")]))
                                                                   ]
                                                                  )
                                         )
                          ]
                         )
}

enum AppAction: Equatable {
    case toggleTimer
    case toggleState
    case timer(time: Double)
    case increment
    case team(id: String, action: TeamAction)
    
    enum TeamAction: Equatable { case game(id: String, action: GameAction) }
    
    enum GameAction: Equatable { case video(id: String, action: VideoAction) }
    
    enum VideoAction: Equatable { case noop }
}

struct AppEnvironment { }

let appReducer = Reducer<AppState, AppAction, AppEnvironment> { state, action, env in
  struct TimerId: Hashable {}
    
  switch action {
        
  case .toggleTimer:
    defer { state.timerOn.toggle() }
    if state.timerOn {
        return .cancel(id: TimerId())
    }
    return Effect.timer(id: TimerId(), every: DispatchQueue.SchedulerTimeType.Stride.milliseconds(30), on: DispatchQueue.main)
        .map { _ in .timer(time: Date().timeIntervalSince1970) }
    
  case .toggleState:
    if state.teams.count ==  1 {
        state = initBigState()
        return .none
    }
    state = AppState()
    return .none
    
  case let .timer(time: time):
    state.masterTime = time
    return .none
    
  case .increment:
    printOn = true
    state.masterTime += 1
    print("appReducer increment time: \(state.masterTime)")
//    state.teams[id: state.currentTeamId]?.array2[id: state.currentGameId]?.array1[id: state.currentVideoId]?.time += 1
//    print("appReducer increment: \(state.teams[id: state.currentTeamId]?.array2[id: state.currentGameId]?.array1[id: state.currentVideoId]?.time ?? .zero)")
    return .none
    
  case .team:
    return .none
  }
}

func initBigState() -> AppState {
    let videos = IdentifiedArrayOf((0..<15).map { index in
        GenericEntity(id: "v\(index)") } )

    let games = IdentifiedArrayOf((0..<5).map { index in
        GenericEntity(id: "g\(index)",
            array1: videos) } )  // videos
    
    let members = IdentifiedArrayOf((0..<5).map { index in
        GenericEntity(id: "m\(index)") } )
    
    let teams = IdentifiedArrayOf((0..<2).map { index in
        GenericEntity(id: "t\(index)",
                    name: "team\(index)",
                    array1: members, // members
                    array2: games) } ) // games
    
    return AppState(currentTeamId: "t\(0)", currentGameId: "g\(0)", currentVideoId: "v\(0)", teams: teams)
}



struct ContentView: View {
    var body: some View {
        MainView(store: Store(initialState: AppState(),
                              reducer: appReducer,
                              environment: AppEnvironment()))
    }
}


struct MainView: View {
    let store: Store<AppState,AppAction>
    
    init(store: Store<AppState,AppAction>) {
        if printOn {
            print("MainView.init called")
        }
        self.store = store
    }
    
    var body: some View {
        if printOn {
            print("MainView.body called")
        }
        
        return WithViewStore(store) { viewStore in
           VStack {
                // Issue: every time button action fires and .counter is incremented ...
                // ... all sub-views' .init and .body get invoked (but their scope do not include masterTime!)
                Button("Increment Timer Value") { viewStore.send(.increment) }
                    .padding(10)
                // Issue: when time gets updated every 30msecs ...
                // ... the cpu% jumps to 92% on iphone 11 in "big state"
                Button(viewStore.timerOn ? "Stop Timer" : "Start Timer (30 msec)") { viewStore.send(.toggleTimer) }
                    .padding(10)
            
                Button(viewStore.teams.count < 2 ? "Move to Big State" : "Move to Small State") { viewStore.send(.toggleState) }
                    .padding(10)

                //   TeamVideoFeature (scope: teams)
                TeamVideoFeature(store: self.store.scope(state: \.scopeTeams))
                    .frame(width: UIScreen.main.bounds.width).background(Color.yellow)
                
                TeamMembers(store: self.store.scope(state: \.scopeTeams))
                    .frame(width: UIScreen.main.bounds.width).background(Color.green)
                //   Recording (scope: game)
                //   Phone Sync (scope: game)
                //   Remote Marking (scope: game)
                //   Profile View (scope: teams)
                TheRest(store: self.store.scope(state: \.scopeTeams))
           }
        }
    }
}

struct TeamVideoFeature: View {
    let store: Store<DeepScopeTeams.State,AppAction>

    init(store: Store<DeepScopeTeams.State,AppAction>) {
        if printOn {
            print("TeamVideoFeature.init called ***************")
        }
        self.store = store
    }

    //    - Team List of Games-Videos (scope: teams)
    //      - Games-Videos (scope: games)
    //        - Game-Videos (scope: game)
    //          - Videos (scope: videos)
    //            - Video (scope: video)
    //    - Game-Videos Detail View (scope: game)
    //      - Video (scope: video)
    //      - Timeline (scope: game)
    //      - Videos List (scope: game)

    var body: some View {
        if printOn {
            print("TeamVideoFeature.body called ***************")
        }
        
        return WithViewStore(store) { viewStore in
            Text("TeamVideoFeature")
            
            ScopeTeams(store: self.store) // Teams List of Games-Videos

            VStack(alignment: .leading) {
                    Text("Game-Videos Detail View (Edit)")
                
                Text("Interactive Video (Edit)")
                DeepScopeVideo(store: self.store.scope(state: \.scopeTeam.scopeGames.scopeGame.scopeVideos.scopeVideo))
                    .background(Color.orange)
                
                Text("Full game timeline")
                HStack(spacing: 1) {
                    //  Timeline (scope: game)
                    DeepScopeGame(store: self.store.scope(state: \.scopeTeam.scopeGames.scopeGame))
                    Spacer()
                }
                
                Text("Thumnbails for all clips")
                HStack(spacing: 1) {
                    // Videos List (scope: game)
                    DeepScopeGame(store: self.store.scope(state: \.scopeTeam.scopeGames.scopeGame))
                    Spacer()
                }
            }
        }
    }
}

struct TeamMembers: View {
    let store: Store<DeepScopeTeams.State,AppAction>

    init(store: Store<DeepScopeTeams.State,AppAction>) {
        if printOn {
            print("TeamVideoFeature.init called ***************")
        }
        self.store = store
    }

    //   Teams List (scope: all)
    //    - Team (scope: team)
    //      - Members List (scope: members)
    //        - Member (scope: member)

    var body: some View {
        if printOn { print("TeamVideoFeature.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            HStack(spacing: 1) {
                DeepScopeTeamMembers(store: self.store.scope(state: \.scopeTeam.scopeMembers)) // Teams List of Games-Videos
                Spacer()
            }
        }
    }
}

struct TheRest: View {
    let store: Store<DeepScopeTeams.State,AppAction>

    init(store: Store<DeepScopeTeams.State,AppAction>) {
        if printOn { print("TeamVideoFeature.init called ***************") }
        self.store = store
    }

    //   Recording (scope: game)
    //   Phone Sync (scope: game)
    //   Remote Marking (scope: game)
    //   Profile View (scope: teams)

    var body: some View {
        if printOn { print("TeamVideoFeature.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("The Rest not implemented for test")
        }
    }
}


extension AppState {
    var scopeTeams: DeepScopeTeams.State {
        get {
            .init(currentTeamId: self.currentTeamId,
                  currentGameId: self.currentGameId,
                  currentVideoId: self.currentVideoId,
                  currentMemberId: self.currentMemberId,
                  teams: self.teams)
        }
        set {
            self.teams = newValue.teams
        }
    }
}

struct ScopeTeams: View {
    let store: Store<DeepScopeTeams.State,AppAction>
    
    init(store: Store<DeepScopeTeams.State,AppAction>) {
        if printOn { print("ScopeTeams.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("ScopeTeams.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                Text("Team List of Games-Videos (Library)")
                ForEachStore(self.store.scope(state: { $0.teams }, action: { AppAction.team(id: $0, action: $1) } )) { team in
                    ScopeTeam(store: team)
                }
            }
        }
    }
}


struct ScopeTeam: View {
    let store: Store<GenericEntity,AppAction.TeamAction>
    
    init(store: Store<GenericEntity,AppAction.TeamAction>) {
        if printOn { print("ScopeTeam.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("ScopeTeam.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            HStack {
                HStack {
                    Text("T").foregroundColor(.white)
                    
                    VStack {
                        ForEachStore(self.store.scope(state: { $0.array2 }, action: { AppAction.TeamAction.game(id: $0, action: $1) } )) { game in
                            ScopeGame(store: game)
                        }
                    }
                }
                .background(Color.pink)
                Spacer()
            }
        }
    }
}

struct ScopeGame: View {
    let store: Store<GenericEntity,AppAction.GameAction>
    
    init(store: Store<GenericEntity,AppAction.GameAction>) {
        if printOn { print("ScopeGame.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("ScopeGame.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            HStack(spacing: 1) {
                Text("G").foregroundColor(.white).background(Color.blue)
                
                ForEachStore(self.store.scope(state: { $0.array1 }, action: { AppAction.GameAction.video(id: $0, action: $1) } )) { video in
                    ScopeVideo(store: video).background(Color.purple)
                }
            }
        }
    }
}

struct ScopeVideo: View {
    let store: Store<GenericEntity,AppAction.VideoAction>
    
    init(store: Store<GenericEntity,AppAction.VideoAction>) {
        if printOn { print("ScopeVideo.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("ScopeVideo.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("\(viewStore.id)").foregroundColor(.white)
        }
    }
}


struct DeepScopeTeams: View {
    let store: Store<DeepScopeTeams.State,AppAction>

    struct State: Equatable {
        let currentTeamId: String
        let currentGameId: String
        let currentVideoId: String
        let currentMemberId: String
        var teams: IdentifiedArrayOf<GenericEntity>
    }
    
    init(store: Store<DeepScopeTeams.State,AppAction>) {
        if printOn { print("DeepScopeTeams.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeTeams.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            ForEach(viewStore.teams) { team in
                DeepScopeTeam(store: self.store.scope(state: \.scopeTeam))
            }
        }
    }
}



extension DeepScopeTeams.State {
    var scopeTeam: DeepScopeTeam.State {
        get {
            .init(currentGameId: self.currentGameId,
                  currentVideoId: self.currentVideoId,
                  currentMemberId: self.currentMemberId,
                  team: self.teams[id: self.currentTeamId] ?? GenericEntity())
        }
        set {
            self.teams[id: self.currentTeamId] = newValue.team
        }
    }
}

struct DeepScopeTeam: View {
    let store: Store<DeepScopeTeam.State,AppAction>

    struct State: Equatable {
        let currentGameId: String
        let currentVideoId: String
        let currentMemberId: String
        var team: GenericEntity
    }
    
    init(store: Store<DeepScopeTeam.State,AppAction>) {
        if printOn { print("DeepScopeTeam.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeTeam.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("T")
            
            DeepScopeGames(store: self.store.scope(state: \.scopeGames))
        }
    }
}

extension DeepScopeTeam.State {
    var scopeGames: DeepScopeGames.State {
        get {
            .init(currentGameId: self.currentGameId,
                  currentVideoId: self.currentVideoId,
                  games: self.team.array2)
        }
        set {
            self.team.array2 = newValue.games
        }
    }
}

struct DeepScopeGames: View {
    let store: Store<DeepScopeGames.State,AppAction>

    struct State: Equatable {
        let currentGameId: String
        let currentVideoId: String
        var games: IdentifiedArrayOf<GenericEntity>
    }
    
    init(store: Store<DeepScopeGames.State,AppAction>) {
        if printOn { print("DeepScopeGames.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeGames.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("Gs")
            
            HStack {
                ForEach(viewStore.games) { game in
                    DeepScopeGame(store: self.store.scope(state: \.scopeGame))
                }
                Spacer()
            }
        }
    }
}

extension DeepScopeGames.State {
    var scopeGame: DeepScopeGame.State {
        get {
            .init(currentVideoId: self.currentVideoId,
                  game: self.games[id: self.currentGameId] ?? GenericEntity())
        }
        set {
            self.games[id: self.currentGameId]? = newValue.game
        }
    }
}

struct DeepScopeGame: View {
    let store: Store<DeepScopeGame.State,AppAction>

    struct State: Equatable {
        let currentVideoId: String
        var game: GenericEntity
    }
    
    init(store: Store<DeepScopeGame.State,AppAction>) {
        if printOn { print("DeepScopeGame.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeGame.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("G").background(Color.blue)
            
//            ForEachStore(self.store.scope(state: { $0.game.array1 }, action: { AppAction.GameAction.video(id: $0, action: $1) } )) { video in
//                ScopeVideo(store: video).background(Color.purple)
//            }
            DeepScopeVideos(store: self.store.scope(state: \.scopeVideos))
        }
    }
}


extension DeepScopeGame.State {
    var scopeVideos: DeepScopeVideos.State {
        get {
            .init(currentVideoId: self.currentVideoId,
                  videos: self.game.array1)
        }
        set {
            self.game.array1 = newValue.videos
        }
    }
}


struct DeepScopeVideos: View {
    let store: Store<DeepScopeVideos.State,AppAction>

    struct State: Equatable {
        let currentVideoId: String
        var videos: IdentifiedArrayOf<GenericEntity>
    }
    
    init(store: Store<DeepScopeVideos.State,AppAction>) {
        if printOn { print("DeepScopeVideos.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeVideos.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            ForEach(viewStore.videos) { video in
                DeepScopeVideo(store: self.store.scope(state: \.scopeVideo))
            }
        }
    }
}

extension DeepScopeVideos.State {
    var scopeVideo: DeepScopeVideo.State {
        get {
            .init(video: self.videos[id: self.currentVideoId] ?? GenericEntity())
        }
        set {
            self.videos[id: self.currentVideoId]? = newValue.video
        }
    }
}


struct DeepScopeVideo: View {
    let store: Store<DeepScopeVideo.State,AppAction>

    struct State: Equatable {
        var video: GenericEntity
    }
    
    init(store: Store<DeepScopeVideo.State,AppAction>) {
        if printOn { print("DeepScopeVideo.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeVideo.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("V").background(Color.orange)
        }
    }
}


extension DeepScopeTeam.State {
    var scopeMembers: DeepScopeTeamMembers.State {
        get {
            .init(currentMemberId: self.currentMemberId,
                  members: self.team.array1)
        }
    }
}

struct DeepScopeTeamMembers: View {
    let store: Store<DeepScopeTeamMembers.State,AppAction>

    struct State: Equatable {
        let currentMemberId: String
        var members: IdentifiedArrayOf<GenericEntity>
    }
    
    init(store: Store<DeepScopeTeamMembers.State,AppAction>) {
        if printOn { print("DeepScopeTeamMembers.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeTeamMembers.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("Ms")
            
            HStack {
                ForEach(viewStore.members) { video in
                    DeepScopeMember(store: self.store.scope(state: \.scopeMember))
                }
                Spacer()
            }
        }
    }
}

extension DeepScopeTeamMembers.State {
    var scopeMember: DeepScopeMember.State {
        get {
            .init(member: self.members[id: self.currentMemberId]!)
        }
        set {
            self.members[id: self.currentMemberId]? = newValue.member
        }
    }
}


struct DeepScopeMember: View {
    let store: Store<DeepScopeMember.State,AppAction>

    struct State: Equatable {
        var member: GenericEntity
    }
    
    init(store: Store<DeepScopeMember.State,AppAction>) {
        if printOn { print("DeepScopeMember.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("DeepScopeMember.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("M")
        }
    }
}

struct GenericEntity: Equatable, Identifiable {
    enum GenericEnum: Equatable {
        case abc
        case def
        case ghi
        case mno
    }

    var id: String = "Bad-\(UUID().uuidString)"
    var time: Double = .zero
    var name: String = ""
    var array1 = IdentifiedArrayOf<GenericEntity>()
    var array2 = IdentifiedArrayOf<GenericEntity>()
    var param1: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    var param2: String = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    var param6: Int = 0
    var param7: Int = 0
    var param23: GenericEnum = .abc
    var param24: GenericEnum = .abc
    var param30: Double = .zero
    var param31: Double = .zero
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

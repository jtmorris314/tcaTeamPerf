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
//      - Video (scope: video)
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
    case printOff
    case team(id: String, action: TeamAction)
    case teamMembers(id: String, action: TeamMembersAction)
    
    enum TeamAction: Equatable { case game(id: String, action: GameAction) }
    
    enum GameAction: Equatable { case video(id: String, action: VideoAction) }
    
    enum VideoAction: Equatable { case noop }
    
    enum TeamMembersAction: Equatable { case member(id: String, action: MemberAction) }
    
    enum MemberAction: Equatable { case noop }
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
//    state.teams[id: state.currentTeamId]?.array2[id: state.currentGameId]?.array1[id: state.currentVideoId]?.time = time
    return .none
    
  case .increment:
    printOn = true
    state.masterTime += 1
    print("appReducer increment time: \(state.masterTime), printOn = true")
//    state.teams[id: state.currentTeamId]?.array2[id: state.currentGameId]?.array1[id: state.currentVideoId]?.time += 1
//    print("appReducer increment: \(state.teams[id: state.currentTeamId]?.array2[id: state.currentGameId]?.array1[id: state.currentVideoId]?.time ?? .zero)")
    return Effect(value: .printOff).delay(for: .milliseconds(10), scheduler: DispatchQueue.main).eraseToEffect()

  case .printOff:
    printOn = false;
    print("printOn = false")
    return .none
    
  case .team:
    return .none
    
  case .teamMembers:
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



let timerMsg =
"""
Start/Stop Timer turns on/off a 30ms timer Effect.
Note: cpu usage 35% for small state (iphone 11)
Note: cpu usage 100% for big state (iphone 11)
No elements of state are tracking the time!
"""

let bigStateMsg =
"""
State changes to/from small and big.
Small:  1 Team, Member, Game, Video
Big:    2 Teams
        5 Members/Team
        5 Games/Team
        15 Videos/Game
Total  172 Elements (big)
Note: "Big state" is really small state. :)
"""

let incrementMsg =
"""
Steps 1 second (and turns printing on).
Note: hits all .init and .body funcs.
"""

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
           ScrollView {
                // Issue: when time gets updated every 30msecs ...
                // ... the cpu% jumps to 92% on iphone 11 in "big state"
                Text(timerMsg)
                Button(viewStore.timerOn ? "Stop Timer" : "Start Timer (30 msec)") { viewStore.send(.toggleTimer) }
                    .padding(10)
            
                Text(bigStateMsg)
                Button(viewStore.teams.count < 2 ? "Move to Big State" : "Move to Small State") { viewStore.send(.toggleState) }
                    .padding(10)
            
                // Issue: every time button action fires and .counter is incremented ...
                // ... all sub-views' .init and .body get invoked (but their scope do not include masterTime!)
                Text(incrementMsg)
                Button("Increment Timer Value") { viewStore.send(.increment) }
                .padding(10)


                //   TeamVideoFeature (scope: teams)
                TeamVideoFeature(store: self.store.scope(state: \.teamVideoFeature))
                    .frame(width: UIScreen.main.bounds.width).background(Color.yellow)
                
                TeamsMembers(store: self.store.scope(state: \.teamsMembers))
                    .frame(width: UIScreen.main.bounds.width).background(Color.green)
                //   Recording (scope: game)
                //   Phone Sync (scope: game)
                //   Remote Marking (scope: game)
                //   Profile View (scope: teams)
                TheRest(store: self.store)
           }
        }
    }
}


extension AppState {
    var teamVideoFeature: TeamVideoFeature.State {
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


struct TeamVideoFeature: View {
    let store: Store<State,AppAction>

    struct State: Equatable {
        let currentTeamId: String
        let currentGameId: String
        let currentVideoId: String
        let currentMemberId: String
        var teams: IdentifiedArrayOf<GenericEntity>
    }

    init(store: Store<State,AppAction>) {
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
            
            ScopeTeams(store: self.store.scope(state: \.scopeTeams)) // Teams List of Games-Videos

            VStack(alignment: .leading) {
                Text("Game-Videos Detail View (Edit)")
                
                Text("Interactive Video (Edit)")
                ScopeVideo(store: self.store.scope(state: { $0.teams[id: $0.currentTeamId]!.array2[id: $0.currentGameId]!.array1[id: $0.currentVideoId]! },
                                                  action: { AppAction.team(id: viewStore.currentTeamId,
                                                                           action: .game(id: viewStore.currentGameId, action: .video(id: viewStore.currentVideoId, action: $0))) } ))
                    
                    .background(Color.orange)
                
                Text("Full game timeline")
                HStack(spacing: 1) {
                    //  Timeline (scope: game)
                    ScopeGame(store: self.store.scope(state: { $0.teams[id: $0.currentTeamId]!.array2[id: $0.currentGameId]! },
                                                      action: { AppAction.team(id: viewStore.currentTeamId,
                                                                               action: .game(id: viewStore.currentGameId, action: $0)) } ))
                    Spacer()
                }
                
                Text("Thumnbails for all clips")
                HStack(spacing: 1) {
                    // Videos List (scope: game)
                    ScopeGame(store: self.store.scope(state: { $0.teams[id: $0.currentTeamId]!.array2[id: $0.currentGameId]! },
                                                      action: { AppAction.team(id: viewStore.currentTeamId,
                                                                               action: .game(id: viewStore.currentGameId, action: $0)) } ))
                    Spacer()
                }
            }
        }
    }
}




struct TheRest: View {
    let store: Store<AppState,AppAction>

    init(store: Store<AppState,AppAction>) {
        if printOn { print("TheRest.init called ***************") }
        self.store = store
    }

    //   Recording (scope: game)
    //   Phone Sync (scope: game)
    //   Remote Marking (scope: game)
    //   Profile View (scope: teams)

    var body: some View {
        if printOn { print("TheRest.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("The Rest not implemented for test")
        }
    }
}


extension TeamVideoFeature.State {
    var scopeTeams: ScopeTeams.State {
        get {
            .init(teams: self.teams)
        }
        set {
            self.teams = newValue.teams
        }
    }
}

struct ScopeTeams: View {
    let store: Store<State,AppAction>
    
    struct State: Equatable {
        var teams: IdentifiedArrayOf<GenericEntity>
    }
    
    init(store: Store<State,AppAction>) {
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
                    Text("\(viewStore.id)").foregroundColor(.white)
                    
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
                Text("\(viewStore.id)").foregroundColor(.white).background(Color.blue)
                
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

extension AppState {
    var teamsMembers: TeamsMembers.State {
        get {
            .init(teams: self.teams)
        }
        set {
            self.teams = newValue.teams
        }
    }
}

struct TeamsMembers: View {
    let store: Store<State,AppAction>
    
    struct State: Equatable {
        var teams: IdentifiedArrayOf<GenericEntity>
    }
    
    init(store: Store<State,AppAction>) {
        if printOn {
            print("TeamsMembers.init called ***************")
        }
        self.store = store
    }
    
    //   Teams List (scope: all)
    //    - Team (scope: team)
    //      - Members List (scope: members)
    //        - Member (scope: member)
    
    var body: some View {
        if printOn { print("TeamsMembers.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            VStack(alignment: .leading) {
                Text("Team List of Members")
                ForEachStore(self.store.scope(state: { $0.teams }, action: { AppAction.teamMembers(id: $0, action: $1) } )) { team in
                    ScopeTeamMembers(store: team)
                }
            }
        }
    }
}
    
struct ScopeTeamMembers: View {
    let store: Store<GenericEntity,AppAction.TeamMembersAction>

    init(store: Store<GenericEntity,AppAction.TeamMembersAction>) {
        if printOn {
            print("ScopeTeamMembers.init called ***************")
        }
        self.store = store
    }

    var body: some View {
        if printOn { print("ScopeTeamMembers.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            HStack(spacing: 1) {
                ForEachStore(self.store.scope(state: { $0.array1 }, action: { AppAction.TeamMembersAction.member(id: $0, action: $1) } )) { member in
                    ScopeTeamMember(store: member)
                }
                Spacer()
            }
        }
    }
}

struct ScopeTeamMember: View {
    let store: Store<GenericEntity,AppAction.MemberAction>

    struct State: Equatable {
        var member: GenericEntity
    }
    
    init(store: Store<GenericEntity,AppAction.MemberAction>) {
        if printOn { print("ScopeTeamMember.init called ***************") }
        self.store = store
    }

    var body: some View {
        if printOn { print("ScopeTeamMember.body called ***************") }
        
        return WithViewStore(store) { viewStore in
            Text("\(viewStore.id)").background(Color.gray)
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

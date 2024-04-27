import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 Composable Architecture에서 여러 독립적인 화면이 상태를 공유하는 방법을 보여줍니다. \
  각 탭은 자체 상태를 관리하며 별도의 모듈에 있을 수 있지만, 한 탭에서의 변경사항은 다른 탭에서 즉시 반영됩니다.

  이 탭은 카운트 값을 증가시키고 감소시킬 수 있는 자체 상태를 가지고 있으며, 현재 카운트가 소수인지 물어볼 때 설정되는 알림 값도 포함하고 있습니다.

  내부적으로는 최소 및 최대 카운트, 발생한 총 카운트 이벤트 수와 같은 다양한 통계를 추적하고 있습니다. \
  이러한 상태는 다른 탭에서 볼 수 있으며, 통계는 다른 탭에서 리셋할 수 있습니다.
  """

@Reducer
struct CounterTab {
  @ObservableState
  struct State: Equatable {
    @Presents var alert: AlertState<Action.Alert>?
    var stats = Stats()
  }

  enum Action {
    case alert(PresentationAction<Alert>)
    case decrementButtonTapped
    case incrementButtonTapped
    case isPrimeButtonTapped

    enum Alert: Equatable {}
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .alert:
        return .none

      case .decrementButtonTapped:
        state.stats.decrement()
        return .none

      case .incrementButtonTapped:
        state.stats.increment()
        return .none

      case .isPrimeButtonTapped:
        state.alert = AlertState {
          TextState(
            isPrime(state.stats.count)
              ? "👍 The number \(state.stats.count) is prime!"
              : "👎 The number \(state.stats.count) is not prime :("
          )
        }
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
  }
}

struct CounterTabView: View {
  @Bindable var store: StoreOf<CounterTab>

  var body: some View {
    Form {
      Text(template: readMe, .caption)

      VStack(spacing: 16) {
        HStack {
          Button {
            store.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(store.stats.count)")
            .monospacedDigit()

          Button {
            store.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }

        Button("Is this prime?") { store.send(.isPrimeButtonTapped) }
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Shared State Demo")
    .alert($store.scope(state: \.alert, action: \.alert))
  }
}

@Reducer
struct ProfileTab {
  @ObservableState
  struct State: Equatable {
    var stats = Stats()
  }

  enum Action {
    case resetStatsButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .resetStatsButtonTapped:
        state.stats.reset()
        return .none
      }
    }
  }
}

struct ProfileTabView: View {
  let store: StoreOf<ProfileTab>

  var body: some View {
    Form {
      Text(
        template: """
          이 탭은 이전 탭의 상태를 보여주며, 모든 상태를 0으로 재설정할 수 있습니다.

          이는 각 화면이 가장 의미 있는 방식으로 자신의 상태를 모델링할 수 있으면서도, 독립적인 화면 간에 상태와 변화를 공유할 수 있음을 보여줍니다.
          """,
        .caption
      )

      VStack(spacing: 16) {
        Text("Current count: \(store.stats.count)")
        Text("Max count: \(store.stats.maxCount)")
        Text("Min count: \(store.stats.minCount)")
        Text("Total number of count events: \(store.stats.numberOfCounts)")
        Button("Reset") { store.send(.resetStatsButtonTapped) }
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Profile")
  }
}

@Reducer
struct SharedState {
  enum Tab { case counter, profile }

  @ObservableState
  struct State: Equatable {
    var currentTab = Tab.counter
    var counter = CounterTab.State()
    var profile = ProfileTab.State()
  }

  enum Action {
    case counter(CounterTab.Action)
    case profile(ProfileTab.Action)
    case selectTab(Tab)
  }

  var body: some Reducer<State, Action> {
    Scope(state: \.counter, action: \.counter) {
      CounterTab()
    }
    .onChange(of: \.counter.stats) { _, stats in
      Reduce { state, _ in
        state.profile.stats = stats
        return .none
      }
    }

    Scope(state: \.profile, action: \.profile) {
      ProfileTab()
    }
    .onChange(of: \.profile.stats) { _, stats in
      Reduce { state, _ in
        state.counter.stats = stats
        return .none
      }
    }

    Reduce { state, action in
      switch action {
      case .counter, .profile:
        return .none
      case let .selectTab(tab):
        state.currentTab = tab
        return .none
      }
    }
  }
}

struct SharedStateView: View {
  @Bindable var store: StoreOf<SharedState>

  var body: some View {
    TabView(selection: $store.currentTab.sending(\.selectTab)) {
      NavigationStack {
        CounterTabView(
          store: self.store.scope(state: \.counter, action: \.counter)
        )
      }
      .tag(SharedState.Tab.counter)
      .tabItem { Text("Counter") }

      NavigationStack {
        ProfileTabView(
          store: self.store.scope(state: \.profile, action: \.profile)
        )
      }
      .tag(SharedState.Tab.profile)
      .tabItem { Text("Profile") }
    }
  }
}

struct Stats: Equatable {
  private(set) var count = 0
  private(set) var maxCount = 0
  private(set) var minCount = 0
  private(set) var numberOfCounts = 0
  mutating func increment() {
    count += 1
    numberOfCounts += 1
    maxCount = max(maxCount, count)
  }
  mutating func decrement() {
    count -= 1
    numberOfCounts += 1
    minCount = min(minCount, count)
  }
  mutating func reset() {
    self = Self()
  }
}

/// Checks if a number is prime or not.
private func isPrime(_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}

#Preview {
  SharedStateView(
    store: Store(initialState: SharedState.State()) {
      SharedState()
    }
  )
}

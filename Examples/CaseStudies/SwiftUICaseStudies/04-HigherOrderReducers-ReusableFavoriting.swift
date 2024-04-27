import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 Composable Architecture에서 재사용 가능한 구성요소를 만드는 방법을 보여줍니다.

  이것은 "즐겨찾기"에 대한 도메인, 로직, 그리고 뷰를 소개하며, 상당히 복잡한 것을 포함합니다.

  기능은 'Favoriting' 리듀서를 사용하고, 적절하게 스코핑된 스토어를 FavoriteButton에 전달함으로써 자신의 상태의 일부를 "즐겨찾기" 할 수 있는 기능을 제공할 수 있습니다.

  행의 즐겨찾기 버튼을 탭하면 UI에 즉시 반영되고 데이터베이스에 쓰기나 API 요청과 같은 필요한 작업을 수행하기 위해 효과가 발생합니다. 우리는 1초 동안 실행되고 25%의 확률로 실패할 수 있는 요청을 시뮬레이션했습니다. 실패는 즐겨찾기 상태를 롤백하고 알림을 표시합니다.
  """

struct FavoritingState<ID: Hashable & Sendable>: Equatable {
  @PresentationState var alert: AlertState<FavoritingAction.Alert>?
  let id: ID
  var isFavorite: Bool
}

@CasePathable
enum FavoritingAction {
  case alert(PresentationAction<Alert>)
  case buttonTapped
  case response(Result<Bool, Error>)

  enum Alert: Equatable {}
}

@Reducer
struct Favoriting<ID: Hashable & Sendable> {
  let favorite: @Sendable (ID, Bool) async throws -> Bool

  private struct CancelID: Hashable {
    let id: AnyHashable
  }

  var body: some Reducer<FavoritingState<ID>, FavoritingAction> {
    Reduce { state, action in
      switch action {
      case .alert(.dismiss):
        state.alert = nil
        state.isFavorite.toggle()
        return .none

      case .buttonTapped:
        state.isFavorite.toggle()

        return .run { [id = state.id, isFavorite = state.isFavorite, favorite] send in
          await send(.response(Result { try await favorite(id, isFavorite) }))
        }
        .cancellable(id: CancelID(id: state.id), cancelInFlight: true)

      case let .response(.failure(error)):
        state.alert = AlertState { TextState(error.localizedDescription) }
        return .none

      case let .response(.success(isFavorite)):
        state.isFavorite = isFavorite
        return .none
      }
    }
  }
}

struct FavoriteButton<ID: Hashable & Sendable>: View {
  let store: Store<FavoritingState<ID>, FavoritingAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Button {
        viewStore.send(.buttonTapped)
      } label: {
        Image(systemName: "heart")
          .symbolVariant(viewStore.isFavorite ? .fill : .none)
      }
      .alert(store: self.store.scope(state: \.$alert, action: \.alert))
    }
  }
}

@Reducer
struct Episode {
  struct State: Equatable, Identifiable {
    var alert: AlertState<FavoritingAction.Alert>?
    let id: UUID
    var isFavorite: Bool
    let title: String

    var favorite: FavoritingState<ID> {
      get { .init(alert: self.alert, id: self.id, isFavorite: self.isFavorite) }
      set { (self.alert, self.isFavorite) = (newValue.alert, newValue.isFavorite) }
    }
  }

  enum Action {
    case favorite(FavoritingAction)
  }

  let favorite: @Sendable (UUID, Bool) async throws -> Bool

  var body: some Reducer<State, Action> {
    Scope(state: \.favorite, action: \.favorite) {
      Favoriting(favorite: self.favorite)
    }
  }
}

struct EpisodeView: View {
  let store: StoreOf<Episode>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      HStack(alignment: .firstTextBaseline) {
        Text(viewStore.title)

        Spacer()

        FavoriteButton(store: self.store.scope(state: \.favorite, action: \.favorite))
      }
    }
  }
}

@Reducer
struct Episodes {
  struct State: Equatable {
    var episodes: IdentifiedArrayOf<Episode.State> = []
  }

  enum Action {
    case episodes(IdentifiedActionOf<Episode>)
  }

  var favorite: @Sendable (UUID, Bool) async throws -> Bool = favoriteRequest

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      .none
    }
    .forEach(\.episodes, action: \.episodes) {
      Episode(favorite: self.favorite)
    }
  }
}

struct EpisodesView: View {
  let store: StoreOf<Episodes>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }
      ForEachStore(self.store.scope(state: \.episodes, action: \.episodes)) { rowStore in
        EpisodeView(store: rowStore)
      }
      .buttonStyle(.borderless)
    }
    .navigationTitle("Favoriting")
  }
}

struct FavoriteError: LocalizedError, Equatable {
  var errorDescription: String? {
    "Favoriting failed."
  }
}

@Sendable private func favoriteRequest<ID>(id: ID, isFavorite: Bool) async throws -> Bool {
  try await Task.sleep(for: .seconds(1))
  if .random(in: 0...1) > 0.25 {
    return isFavorite
  } else {
    throw FavoriteError()
  }
}

extension IdentifiedArray where ID == Episode.State.ID, Element == Episode.State {
  static let mocks: Self = [
    Episode.State(id: UUID(), isFavorite: false, title: "Functions"),
    Episode.State(id: UUID(), isFavorite: false, title: "Side Effects"),
    Episode.State(id: UUID(), isFavorite: false, title: "Algebraic Data Types"),
    Episode.State(id: UUID(), isFavorite: false, title: "DSLs"),
    Episode.State(id: UUID(), isFavorite: false, title: "Parsers"),
    Episode.State(id: UUID(), isFavorite: false, title: "Composable Architecture"),
  ]
}

#Preview {
  NavigationStack {
    EpisodesView(
      store: Store(initialState: Episodes.State(episodes: .mocks)) {
        Episodes()
      }
    )
  }
}

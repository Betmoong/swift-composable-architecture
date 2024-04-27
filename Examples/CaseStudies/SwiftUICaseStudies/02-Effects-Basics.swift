import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 Composable Architecture를 사용하여 기능에 사이드 이펙트를 도입하는 방법을 보여줍니다.

  사이드 이펙트는 외부 세계에서 수행되어야 하는 작업 단위입니다. 예를 들어, API 요청은 HTTP를 통해 외부 서비스에 도달해야 하며, 이는 많은 불확실성과 복잡성을 수반합니다.

  우리의 애플리케이션에서 수행하는 많은 작업들은 타이머, 데이터베이스 요청, 파일 접근, 소켓 연결, 그리고 디바운싱, 스로틀링, 딜레이와 같이 시계가 관여하는 경우 등 사이드 이펙트를 포함하며, 이들은 일반적으로 테스트하기 어렵습니다.

  이 애플리케이션은 간단한 사이드 이펙트를 가지고 있습니다: "Number fact" 버튼을 탭하면 그 숫자에 대한 재미있는 사실을 불러오는 API 요청이 트리거됩니다. 이 효과는 리듀서에 의해 처리되며, 이 효과가 우리가 기대하는 방식으로 동작하는지 확인하기 위해 전체 테스트 스위트가 작성되었습니다.
  """

@Reducer
struct EffectsBasics {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var isNumberFactRequestInFlight = false
    var numberFact: String?
  }

  enum Action {
    case decrementButtonTapped
    case decrementDelayResponse
    case incrementButtonTapped
    case numberFactButtonTapped
    case numberFactResponse(Result<String, Error>)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.factClient) var factClient
  private enum CancelID { case delay }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        state.numberFact = nil
        // Return an effect that re-increments the count after 1 second if the count is negative
        return state.count >= 0
          ? .none
          : .run { send in
            try await self.clock.sleep(for: .seconds(1))
            await send(.decrementDelayResponse)
          }
          .cancellable(id: CancelID.delay)

      case .decrementDelayResponse:
        if state.count < 0 {
          state.count += 1
        }
        return .none

      case .incrementButtonTapped:
        state.count += 1
        state.numberFact = nil
        return state.count >= 0
          ? .cancel(id: CancelID.delay)
          : .none

      case .numberFactButtonTapped:
        state.isNumberFactRequestInFlight = true
        state.numberFact = nil
        // Return an effect that fetches a number fact from the API and returns the
        // value back to the reducer's `numberFactResponse` action.
        return .run { [count = state.count] send in
          await send(.numberFactResponse(Result { try await self.factClient.fetch(count) }))
        }

      case let .numberFactResponse(.success(response)):
        state.isNumberFactRequestInFlight = false
        state.numberFact = response
        return .none

      case .numberFactResponse(.failure):
        // NB: This is where we could handle the error is some way, such as showing an alert.
        state.isNumberFactRequestInFlight = false
        return .none
      }
    }
  }
}

struct EffectsBasicsView: View {
  let store: StoreOf<EffectsBasics>
  @Environment(\.openURL) var openURL

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Section {
        HStack {
          Button {
            store.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(store.count)")
            .monospacedDigit()

          Button {
            store.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
        .frame(maxWidth: .infinity)

        Button("Number fact") { store.send(.numberFactButtonTapped) }
          .frame(maxWidth: .infinity)

        if store.isNumberFactRequestInFlight {
          ProgressView()
            .frame(maxWidth: .infinity)
            // NB: There seems to be a bug in SwiftUI where the progress view does not show
            // a second time unless it is given a new identity.
            .id(UUID())
        }

        if let numberFact = store.numberFact {
          Text(numberFact)
        }
      }

      Section {
        Button("Number facts provided by numbersapi.com") {
          openURL(URL(string: "http://numbersapi.com")!)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Effects")
  }
}

#Preview {
  NavigationStack {
    EffectsBasicsView(
      store: Store(initialState: EffectsBasics.State()) {
        EffectsBasics()
      }
    )
  }
}

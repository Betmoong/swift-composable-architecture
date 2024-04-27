import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 화면은 Composable Architecture에서 실행 중인 효과를 어떻게 취소할 수 있는지 보여줍니다.

  스테퍼를 사용하여 숫자를 세고, "Number fact" 버튼을 눌러 API를 사용하여 해당 숫자에 대한 임의의 사실을 가져옵니다.

  API 요청이 진행 중인 동안 "Cancel"을 탭하면 효과를 취소하고 데이터가 애플리케이션으로 되돌아오는 것을 막을 수 있습니다. 요청이 진행 중일 때 스테퍼를 조작해도 요청이 취소됩니다.
  """

@Reducer
struct EffectsCancellation {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var currentFact: String?
    var isFactRequestInFlight = false
  }

  enum Action {
    case cancelButtonTapped
    case stepperChanged(Int)
    case factButtonTapped
    case factResponse(Result<String, Error>)
  }

  @Dependency(\.factClient) var factClient
  private enum CancelID { case factRequest }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .cancelButtonTapped:
        state.isFactRequestInFlight = false
        return .cancel(id: CancelID.factRequest)

      case let .stepperChanged(value):
        state.count = value
        state.currentFact = nil
        state.isFactRequestInFlight = false
        return .cancel(id: CancelID.factRequest)

      case .factButtonTapped:
        state.currentFact = nil
        state.isFactRequestInFlight = true

        return .run { [count = state.count] send in
          await send(.factResponse(Result { try await self.factClient.fetch(count) }))
        }
        .cancellable(id: CancelID.factRequest)

      case let .factResponse(.success(response)):
        state.isFactRequestInFlight = false
        state.currentFact = response
        return .none

      case .factResponse(.failure):
        state.isFactRequestInFlight = false
        return .none
      }
    }
  }
}

struct EffectsCancellationView: View {
  @Bindable var store: StoreOf<EffectsCancellation>
  @Environment(\.openURL) var openURL

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Section {
        Stepper("\(store.count)", value: $store.count.sending(\.stepperChanged))

        if store.isFactRequestInFlight {
          HStack {
            Button("Cancel") { store.send(.cancelButtonTapped) }
            Spacer()
            ProgressView()
              // NB: There seems to be a bug in SwiftUI where the progress view does not show
              // a second time unless it is given a new identity.
              .id(UUID())
          }
        } else {
          Button("Number fact") { store.send(.factButtonTapped) }
            .disabled(store.isFactRequestInFlight)
        }

        if let fact = store.currentFact {
          Text(fact).padding(.vertical, 8)
        }
      }

      Section {
        Button("Number facts provided by numbersapi.com") {
          self.openURL(URL(string: "http://numbersapi.com")!)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Effect cancellation")
  }
}

#Preview {
  NavigationStack {
    EffectsCancellationView(
      store: Store(initialState: EffectsCancellation.State()) {
        EffectsCancellation()
      }
    )
  }
}

import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 예제는 Composable Architecture에서 SwiftUI의 @FocusState와 라이브러리의 bind 뷰 수정자를 사용하는 방법을 보여줍니다.
  "Sign in" 버튼을 누를 때 필드가 비어 있으면 포커스가 첫 번째 비어 있는 필드로 변경됩니다.
  """

@Reducer
struct FocusDemo {
  @ObservableState
  struct State: Equatable {
    var focusedField: Field?
    var password: String = ""
    var username: String = ""

    enum Field: String, Hashable {
      case username, password
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case signInButtonTapped
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding:
        return .none

      case .signInButtonTapped:
        if state.username.isEmpty {
          state.focusedField = .username
        } else if state.password.isEmpty {
          state.focusedField = .password
        }
        return .none
      }
    }
  }
}

struct FocusDemoView: View {
  @Bindable var store: StoreOf<FocusDemo>
  @FocusState var focusedField: FocusDemo.State.Field?

  var body: some View {
    Form {
      AboutView(readMe: readMe)

      VStack {
        TextField("Username", text: $store.username)
          .focused($focusedField, equals: .username)
        SecureField("Password", text: $store.password)
          .focused($focusedField, equals: .password)
        Button("Sign In") {
          store.send(.signInButtonTapped)
        }
        .buttonStyle(.borderedProminent)
      }
      .textFieldStyle(.roundedBorder)
    }
    // Synchronize store focus state and local focus state.
    .bind($store.focusedField, to: $focusedField)
    .navigationTitle("Focus demo")
  }
}

#Preview {
  NavigationStack {
    FocusDemoView(
      store: Store(initialState: FocusDemo.State()) {
        FocusDemo()
      }
    )
  }
}

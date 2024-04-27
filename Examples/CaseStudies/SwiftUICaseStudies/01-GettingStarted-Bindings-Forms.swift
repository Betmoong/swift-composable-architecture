import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 파일은 Composable Architecture에서 BindableAction과 BindingReducer를 사용하여 양방향 바인딩을 처리하는 방법을 보여줍니다.

  바인더블 액션은 모든 UI 컨트롤마다 고유한 액션이 필요하다는 요구로 인해 발생하는 보일러플레이트를 안전하게 제거할 수 있게 해줍니다. \
  대신, 모든 UI 바인딩은 단일 binding 액션으로 통합될 수 있으며, BindingReducer는 이를 자동으로 상태에 적용할 수 있습니다.

  이 케이스 스터디를 "Binding Basics" 케이스 스터디와 비교하는 것이 교육적입니다.
  """

@Reducer
struct BindingForm {
  @ObservableState
  struct State: Equatable {
    var sliderValue = 5.0
    var stepCount = 10
    var text = ""
    var toggleIsOn = false
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case resetButtonTapped
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding(\.stepCount):
        state.sliderValue = .minimum(state.sliderValue, Double(state.stepCount))
        return .none

      case .binding:
        return .none

      case .resetButtonTapped:
        state = State()
        return .none
      }
    }
  }
}

struct BindingFormView: View {
  @Bindable var store: StoreOf<BindingForm>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        TextField("Type here", text: $store.text)
          .disableAutocorrection(true)
          .foregroundStyle(store.toggleIsOn ? Color.secondary : .primary)
        Text(alternate(store.text))
      }
      .disabled(store.toggleIsOn)

      Toggle("Disable other controls", isOn: $store.toggleIsOn.resignFirstResponder())

      Stepper(
        "Max slider value: \(store.stepCount)",
        value: $store.stepCount,
        in: 0...100
      )
      .disabled(store.toggleIsOn)

      HStack {
        Text("Slider value: \(Int(store.sliderValue))")

        Slider(value: $store.sliderValue, in: 0...Double(store.stepCount))
          .tint(.accentColor)
      }
      .disabled(store.toggleIsOn)

      Button("Reset") {
        store.send(.resetButtonTapped)
      }
      .tint(.red)
    }
    .monospacedDigit()
    .navigationTitle("Bindings form")
  }
}

private func alternate(_ string: String) -> String {
  string
    .enumerated()
    .map { idx, char in
      idx.isMultiple(of: 2)
        ? char.uppercased()
        : char.lowercased()
    }
    .joined()
}

#Preview {
  NavigationStack {
    BindingFormView(
      store: Store(initialState: BindingForm.State()) {
        BindingForm()
      }
    )
  }
}

import ComposableArchitecture
import SwiftUI

private let readMe = """
  이 파일은 Composable Architecture에서 양방향 바인딩을 다루는 방법을 보여줍니다.

  SwiftUI의 양방향 바인딩은 강력하지만, Composable Architecture의 "단방향 데이터 흐름"과는 배치됩니다. \
  이는 값이 언제든지 원하는 대로 변경될 수 있기 때문입니다.

  반면, Composable Architecture는 변경사항이 스토어에 액션을 보내는 것을 통해서만 발생할 수 있도록 요구하며, \
  이는 우리의 기능의 상태가 어떻게 발전하는지 확인할 수 있는 곳이 오직 리듀서뿐임을 의미합니다.

  작업을 수행하기 위해 바인딩이 필요한 모든 SwiftUI 컴포넌트는 Composable Architecture에서 사용될 수 있습니다. \
  스토어에서 바인딩을 파생시키려면 바인딩 가능한 스토어를 취하고, 컴포넌트를 렌더링하는 상태의 속성으로 연결한 다음, \
  컴포넌트가 변경될 때 보낼 액션의 키 경로와 함께 sending 메소드를 호출함으로써, 기능에 대한 단방향 스타일을 계속 사용할 수 있습니다.
  """

@Reducer
struct BindingBasics {
  @ObservableState
  struct State: Equatable {
    var sliderValue = 5.0
    var stepCount = 10
    var text = ""
    var toggleIsOn = false
  }

  enum Action {
    case sliderValueChanged(Double)
    case stepCountChanged(Int)
    case textChanged(String)
    case toggleChanged(isOn: Bool)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .sliderValueChanged(value):
        state.sliderValue = value
        return .none

      case let .stepCountChanged(count):
        state.sliderValue = .minimum(state.sliderValue, Double(count))
        state.stepCount = count
        return .none

      case let .textChanged(text):
        state.text = text
        return .none

      case let .toggleChanged(isOn):
        state.toggleIsOn = isOn
        return .none
      }
    }
  }
}

struct BindingBasicsView: View {
  @Bindable var store: StoreOf<BindingBasics>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        TextField("Type here", text: $store.text.sending(\.textChanged))
          .disableAutocorrection(true)
          .foregroundStyle(store.toggleIsOn ? Color.secondary : .primary)
        Text(alternate(store.text))
      }
      .disabled(store.toggleIsOn)

      Toggle(
        "Disable other controls",
        isOn: $store.toggleIsOn.sending(\.toggleChanged).resignFirstResponder()
      )

      Stepper(
        "Max slider value: \(store.stepCount)",
        value: $store.stepCount.sending(\.stepCountChanged),
        in: 0...100
      )
      .disabled(store.toggleIsOn)

      HStack {
        Text("Slider value: \(Int(store.sliderValue))")
        Slider(
          value: $store.sliderValue.sending(\.sliderValueChanged),
          in: 0...Double(store.stepCount)
        )
        .tint(.accentColor)
      }
      .disabled(store.toggleIsOn)
    }
    .monospacedDigit()
    .navigationTitle("Bindings basics")
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
    BindingBasicsView(
      store: Store(initialState: BindingBasics.State()) {
        BindingBasics()
      }
    )
  }
}

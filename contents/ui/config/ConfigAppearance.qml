import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {

    property alias cfg_backgroundOpacity: opacitySlider.value

    Kirigami.FormLayout {
        anchors.fill: parent

        RowLayout {
            Kirigami.FormData.label: "Transparence du fond :"

            QQC2.Slider {
                id: opacitySlider
                from: 0.0
                to: 1.0
                stepSize: 0.05
                Layout.fillWidth: true
            }
            QQC2.Label {
                text: Math.round(opacitySlider.value * 100) + "%"
                Layout.minimumWidth: 40
            }
        }
    }
}

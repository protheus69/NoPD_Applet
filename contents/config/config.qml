import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: "Apparence"
        icon: "preferences-desktop-color"
        source: "config/ConfigAppearance.qml"
    }
}

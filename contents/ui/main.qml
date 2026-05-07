import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation
    implicitWidth: 320
    implicitHeight: 480

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    property real bgOpacity: Plasmoid.configuration.backgroundOpacity

    // ── État interne ──────────────────────────────────────────────
    property int    hibernate:        0
    property int    sleepTimeout:     15
    property int    hibernateTimeout: 15
    property string lidAction:        "hibernate"
    property string lastStatus:       "Prêt."
    property bool   applying:         false

    // Flag pour distinguer lecture / écriture dans onNewData
    property bool   isReading:        false

    // ── DataSource ────────────────────────────────────────────────
    P5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(source, data) {
            var out  = (data["stdout"] || "").trim()
            var err  = (data["stderr"] || "").trim()
            var exit = data["exit code"] !== undefined ? data["exit code"] : 0
            disconnectSource(source)

            if (root.isReading) {
                root.isReading = false
                if (out !== "") {
                    parseConfig(out)
                    root.lastStatus = "✓ Config chargée."
                } else {
                    root.lastStatus = "⚠ Config introuvable, valeurs par défaut."
                }
            } else {
                root.applying = false
                root.lastStatus = (exit === 0)
                    ? "✓ Config sauvegardée."
                    : "✗ Erreur (" + exit + ")" + (err ? " : " + err : "")
            }
        }
    }

    // ── Parsing KEY=value ─────────────────────────────────────────
    function parseConfig(text) {
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line.startsWith("#") || line === "") continue
            var idx = line.indexOf("=")
            if (idx < 0) continue
            var key = line.substring(0, idx).trim()
            var val = line.substring(idx + 1).trim()
            if (key === "HIBERNATE")          root.hibernate         = parseInt(val, 10) || 0
            if (key === "SLEEP_TIMEOUT")      root.sleepTimeout      = parseInt(val, 10) || 15
            if (key === "HIBERNATE_TIMEOUT")  root.hibernateTimeout  = parseInt(val, 10) || 15
            if (key === "LID_ACTION")         root.lidAction         = val
        }
        // Force la mise à jour du slider
        timeoutSlider.value = root.hibernate ? root.hibernateTimeout : root.sleepTimeout
    }

    // ── Lecture ───────────────────────────────────────────────────
    function loadConfig() {
        root.lastStatus = "Lecture…"
        root.isReading = true
        executable.connectSource("bash -c 'cat $HOME/.config/inactivity/config 2>/dev/null'")
    }

    // ── Écriture ──────────────────────────────────────────────────
    function applyConfig() {
        root.applying = true
        root.isReading = false
        root.lastStatus = "Sauvegarde…"

        var content = "HIBERNATE="         + root.hibernate         + "\\n"
                    + "SLEEP_TIMEOUT="     + root.sleepTimeout      + "\\n"
                    + "HIBERNATE_TIMEOUT=" + root.hibernateTimeout  + "\\n"
                    + "LID_ACTION="        + root.lidAction         + "\\n"

        var cmd = "bash -c 'mkdir -p $HOME/.config/inactivity && printf \""
                + content
                + "\" > $HOME/.config/inactivity/config'"

        executable.connectSource(cmd)
    }

    // ── Chargement initial ────────────────────────────────────────
    Component.onCompleted: loadConfig()

    // ── UI ────────────────────────────────────────────────────────
    fullRepresentation: Rectangle {
        color: Qt.rgba(
            Kirigami.Theme.backgroundColor.r,
            Kirigami.Theme.backgroundColor.g,
            Kirigami.Theme.backgroundColor.b,
            root.bgOpacity
        )
        radius: 8

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10

            // En-tête
            RowLayout {
                Layout.fillWidth: true
                Kirigami.Icon {
                    source: "system-suspend"
                    implicitWidth: 20; implicitHeight: 20
                }
                PlasmaComponents.Label {
                    text: "Inactivity Manager"
                    font.bold: true
                    font.pixelSize: 15
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    radius: 4
                    color: root.hibernate === 1 ? "#3d5a80" : "#2d7d46"
                    implicitWidth: modeLbl.implicitWidth + 14
                    Layout.maximumWidth: implicitWidth
                    height: 22
                    PlasmaComponents.Label {
                        id: modeLbl
                        anchors.centerIn: parent
                        text: root.hibernate === 1 ? "Hibernation" : "Veille"
                        font.pixelSize: 11; font.bold: true; color: "white"
                    }
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // Mode de suspension
            PlasmaComponents.Label {
                text: "Mode de suspension"
                font.pixelSize: 11
                color: "white"
                //color: Kirigami.Theme.disabledTextColor
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                PlasmaComponents.Button {
                    Layout.fillWidth: true; text: "Veille"
                    highlighted: root.hibernate === 0
                    onClicked: {
                        root.hibernate = 0
                        timeoutSlider.value = root.sleepTimeout
                    }
                }
                PlasmaComponents.Button {
                    Layout.fillWidth: true; text: "Hibernation"
                    highlighted: root.hibernate === 1
                    onClicked: {
                        root.hibernate = 1
                        timeoutSlider.value = root.hibernateTimeout
                    }
                }
            }

            // Délai d'inactivité
            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label {
                    text: "Délai d'inactivité"
                    font.pixelSize: 11
                    color: "white"
                    //color: Kirigami.Theme.disabledTextColor
                }
                Item { Layout.fillWidth: true }
                PlasmaComponents.Label {
                    text: (root.hibernate === 1 ? root.hibernateTimeout : root.sleepTimeout) + " min"
                    font.bold: true; font.pixelSize: 12
                }
            }

            // Slider sans liaison automatique — géré manuellement
            QQC2.Slider {
                id: timeoutSlider
                Layout.fillWidth: true
                from: 1; to: 60; stepSize: 1
                value: root.sleepTimeout   // valeur initiale seulement
                onMoved: {
                    if (root.hibernate === 1) root.hibernateTimeout = Math.round(value)
                    else                      root.sleepTimeout     = Math.round(value)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlasmaComponents.Label { text: "1 min";  font.pixelSize: 10; color: "white" } //Kirigami.Theme.disabledTextColor }
                Item { Layout.fillWidth: true }
                PlasmaComponents.Label { text: "60 min"; font.pixelSize: 10; color: "white" } //Kirigami.Theme.disabledTextColor }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // Fermeture du couvercle
            PlasmaComponents.Label {
                text: "Fermeture du couvercle"
                font.pixelSize: 11
                color: "white"
                //color: Kirigami.Theme.disabledTextColor
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 6
                PlasmaComponents.Button {
                    Layout.fillWidth: true; text: "Hiberner"
                    highlighted: root.lidAction === "hibernate"
                    onClicked: root.lidAction = "hibernate"
                }
                PlasmaComponents.Button {
                    Layout.fillWidth: true; text: "Veille"
                    highlighted: root.lidAction === "suspend"
                    onClicked: root.lidAction = "suspend"
                }
                PlasmaComponents.Button {
                    Layout.fillWidth: true; text: "Ignorer"
                    highlighted: root.lidAction === "ignore"
                    onClicked: root.lidAction = "ignore"
                }
            }

            Kirigami.Separator { Layout.fillWidth: true }

            // Barre de statut
            Rectangle {
                Layout.fillWidth: true; height: 30; radius: 5
                color: Kirigami.Theme.alternateBackgroundColor
                PlasmaComponents.Label {
                    anchors.centerIn: parent
                    text: root.lastStatus
                    font.pixelSize: 11
                    color: root.lastStatus.startsWith("✓")
                         ? Kirigami.Theme.positiveTextColor
                         : root.lastStatus.startsWith("✗")
                         ? Kirigami.Theme.negativeTextColor
                         : Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    width: parent.width - 12
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            // Boutons
            PlasmaComponents.Button {
                Layout.fillWidth: true
                text: root.applying ? "Application…" : "Appliquer & Sauvegarder"
                enabled: !root.applying
                icon.name: "dialog-ok-apply"
                onClicked: root.applyConfig()
            }
            PlasmaComponents.Button {
                Layout.fillWidth: true
                text: "Relire la config"
                icon.name: "view-refresh"
                flat: true
                onClicked: root.loadConfig()
            }
        }
    }
}

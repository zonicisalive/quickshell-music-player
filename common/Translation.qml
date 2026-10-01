pragma Singleton
import QtQuick

// The shell translates UI strings; standalone, they show as written.
QtObject {
    function tr(text: string): string {
        return text;
    }
}

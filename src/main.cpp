#include <QApplication>

#include "distrust.h"
#include "mainwindow.h"

int main(int argc, char *argv[])
{
    // Before QtWebEngine starts: Chromium must find NSS closed.
    if (!distrustCompromisedCertificates()) {
        return 1;
    }

    QCoreApplication::setOrganizationName("e1z0");
    QApplication a(argc, argv);

    // On the stack: the page must go before QApplication tears the profile down.
    MainWindow mainWindow;
    mainWindow.show();

    return a.exec();
}

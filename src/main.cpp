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

    MainWindow* mainWindow = new MainWindow();
    mainWindow->show();

    return a.exec();
}

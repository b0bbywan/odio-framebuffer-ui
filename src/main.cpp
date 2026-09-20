#include <QApplication>

#include "mainwindow.h"

int main(int argc, char *argv[])
{
    QCoreApplication::setOrganizationName("e1z0");
    QApplication a(argc, argv);

    MainWindow* mainWindow = new MainWindow();
    mainWindow->show();

    return a.exec();
}

#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>
#include <QMenu>
#include <QWidget>
#include <QShortcut>
// QtWebEngineCore since Qt 6, but the forwarding headers keep these working.
#include <QWebEngineFullScreenRequest>
#include <QWebEnginePage>
#include <QWebEngineView>

class MainWindow : public QMainWindow {
  Q_OBJECT

  // Define signals and slots
  QString optStartupUrl;
  int optWidth = 0;
  int optHeight = 0;
  QString optProxyHost = "";
  int optProxyPort = 0;

 public:
  QWebEngineView *webView;
  explicit MainWindow();
  ~MainWindow();
  void configureWebView();
  void loadConfig();
  void loadUrl(QString url);

 public slots:
  void loadStartupUrl();
  void onLoadStarted();
  void slotShortcutCtrlQ();
  void slotShortcutBack();
  void slotShortcutForward();
 private:
  QShortcut *keyCtrlQ; // Entity of Ctrl + Q hotkeys
  QShortcut *keyBack; // back in history
  QShortcut *keyForward; // forward in history
  void fullScreenRequested(QWebEngineFullScreenRequest request);
};

#endif  // MAINWINDOW_H

#include "distrust.h"

// Before Qt: secmodt.h has a member named slots, which Qt defines as a macro.
#include <cert.h>
#include <certdb.h>
#include <nss.h>
#include <pk11pub.h>

#include <QDebug>
#include <QDir>
#include <QFile>

namespace {

bool distrust(CERTCertDBHandle *db, PK11SlotInfo *slot, const QFileInfo &file) {
  QFile f(file.filePath());
  if (!f.open(QIODevice::ReadOnly)) {
    qCritical() << "distrust: cannot read" << file.filePath();
    return false;
  }
  QByteArray pem = f.readAll();
  CERTCertificate *decoded = CERT_DecodeCertFromPackage(pem.data(), pem.size());
  if (!decoded) {
    qCritical() << "distrust: cannot decode" << file.fileName();
    return false;
  }

  bool ok = true;
  QByteArray nickname = ("odio-kiosk distrust " + file.completeBaseName()).toUtf8();
  if (PK11_FindCertInSlot(slot, decoded, nullptr) == CK_INVALID_HANDLE
      && PK11_ImportCert(slot, decoded, CK_INVALID_HANDLE, nickname.constData(), PR_FALSE) != SECSuccess) {
    ok = false;
  }

  CERTCertificate *stored = ok ? CERT_FindCertByDERCert(db, &decoded->derCert) : nullptr;
  CERTCertTrust trust;
  // "p" alone: a terminal record with no trust bit, which Chromium reads as distrusted.
  if (!stored || CERT_DecodeTrustString(&trust, "p,p,p") != SECSuccess
      || CERT_ChangeCertTrust(db, stored, &trust) != SECSuccess) {
    ok = false;
  }
  if (!ok) {
    qCritical() << "distrust:" << file.fileName() << "NSS error" << PORT_GetError();
  }

  if (stored) CERT_DestroyCertificate(stored);
  CERT_DestroyCertificate(decoded);
  return ok;
}

}  // namespace

bool distrustCompromisedCertificates() {
  // QtWebEngine 6.8 (Chromium 122) reads user trust settings from this DB.
  QString dir = QDir::homePath() + "/.pki/nssdb";
  if (!QDir().mkpath(dir)) {
    qCritical() << "distrust: cannot create" << dir;
    return false;
  }

  QByteArray config = ("sql:" + dir).toUtf8();
  NSSInitContext *ctx = NSS_InitContext(config.constData(), "", "", "", nullptr, NSS_INIT_NOROOTINIT);
  if (!ctx) {
    qCritical() << "distrust: cannot open" << dir << "NSS error" << PORT_GetError();
    return false;
  }

  bool ok = true;
  PK11SlotInfo *slot = PK11_GetInternalKeySlot();
  // A new DB gets an empty password, as certutil -N --empty-password would set.
  if (PK11_NeedUserInit(slot) && PK11_InitPin(slot, nullptr, nullptr) != SECSuccess) {
    qCritical() << "distrust: cannot initialize" << dir << "NSS error" << PORT_GetError();
    ok = false;
  }
  const QFileInfoList files = QDir(":/distrust").entryInfoList(QDir::Files, QDir::Name);
  for (const QFileInfo &file : files) {
    ok = ok && distrust(CERT_GetDefaultCertDB(), slot, file);
  }
  PK11_FreeSlot(slot);

  // The last context closes NSS, so Chromium initializes it afresh.
  if (NSS_ShutdownContext(ctx) != SECSuccess) {
    qCritical() << "distrust: cannot close" << dir << "NSS error" << PORT_GetError();
    ok = false;
  }
  return ok && !files.isEmpty();
}

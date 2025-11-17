const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// Настройте транспортер для отправки email (пример для Gmail)
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: functions.config().gmail.email, // Настройте через: firebase functions:config:set gmail.email="your@gmail.com"
    pass: functions.config().gmail.password // firebase functions:config:set gmail.password="app-password"
  }
});

// Функция для отправки кода подтверждения
exports.sendVerificationCode = functions.https.onCall(async (data, context) => {
  const { email, firstName } = data;
  
  // Генерируем 6-значный код
  const verificationCode = Math.floor(100000 + Math.random() * 900000).toString();
  
  // Сохраняем код в Firestore с временной меткой
  await admin.firestore().collection('verificationCodes').doc(email).set({
    code: verificationCode,
    email: email,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: new Date(Date.now() + 10 * 60 * 1000) // Код действителен 10 минут
  });

  // Отправляем email
  const mailOptions = {
    from: functions.config().gmail.email,
    to: email,
    subject: 'Код подтверждения для регистрации',
    html: `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2 style="color: #4CAF50;">Подтверждение регистрации</h2>
        <p>Здравствуйте, ${firstName}!</p>
        <p>Ваш код подтверждения для регистрации:</p>
        <div style="background-color: #f5f5f5; padding: 15px; text-align: center; font-size: 24px; font-weight: bold; letter-spacing: 5px; margin: 20px 0;">
          ${verificationCode}
        </div>
        <p>Этот код действителен в течение 10 минут.</p>
        <p>Если вы не запрашивали регистрацию, проигнорируйте это письмо.</p>
        <hr>
        <p style="color: #666; font-size: 12px;">Это автоматическое сообщение, пожалуйста, не отвечайте на него.</p>
      </div>
    `
  };

  try {
    await transporter.sendMail(mailOptions);
    return { success: true, message: 'Код отправлен на email' };
  } catch (error) {
    console.error('Ошибка отправки email:', error);
    throw new functions.https.HttpsError('internal', 'Не удалось отправить код подтверждения');
  }
});

// Функция для проверки кода
exports.verifyCode = functions.https.onCall(async (data, context) => {
  const { email, code } = data;

  // Получаем запись с кодом
  const codeDoc = await admin.firestore().collection('verificationCodes').doc(email).get();
  
  if (!codeDoc.exists) {
    throw new functions.https.HttpsError('not-found', 'Код не найден или истек');
  }

  const codeData = codeDoc.data();
  const now = new Date();
  const expiresAt = codeData.expiresAt.toDate();

  // Проверяем срок действия кода
  if (now > expiresAt) {
    // Удаляем просроченный код
    await admin.firestore().collection('verificationCodes').doc(email).delete();
    throw new functions.https.HttpsError('deadline-exceeded', 'Срок действия кода истек');
  }

  // Проверяем код
  if (codeData.code !== code) {
    throw new functions.https.HttpsError('invalid-argument', 'Неверный код подтверждения');
  }

  // Код верный, удаляем его из базы
  await admin.firestore().collection('verificationCodes').doc(email).delete();

  return { 
    success: true, 
    message: 'Email успешно подтвержден',
    verified: true
  };
});
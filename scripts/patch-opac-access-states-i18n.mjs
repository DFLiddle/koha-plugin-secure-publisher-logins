#!/usr/bin/env node
'use strict';
/**
 * Add OPAC access-state msgids (v1.4.x) to po/catalogs.json.
 * Run: node scripts/patch-opac-access-states-i18n.mjs
 * Then: npm run i18n:po && npm run i18n:verify
 */
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const catalogsPath = path.join(__dirname, '..', 'po', 'catalogs.json');

export const OPAC_ACCESS_STATE_MSGIDS = [
  'Log in to check access',
  'Library not subscribed',
  'Login info not available',
  'Your library is not subscribed to this online resource. Click the link below to suggest it for purchase.',
  'Suggest for purchase',
  'Your account requires attention before the login info can be shown. Please write to %s for help.',
];

/** locale -> [msgstr…] in OPAC_ACCESS_STATE_MSGIDS order */
const LOCALE_MSGSTRS = {
  'id-ID': [
    'Masuk untuk memeriksa akses',
    'Perpustakaan tidak berlangganan',
    'Info login tidak tersedia',
    'Perpustakaan Anda tidak berlangganan sumber daring ini. Klik tautan di bawah untuk mengusulkan pembelian.',
    'Usulkan untuk dibeli',
    'Akun Anda memerlukan perhatian sebelum info login dapat ditampilkan. Silakan tulis ke %s untuk bantuan.',
  ],
  'th-TH': [
    'เข้าสู่ระบบเพื่อตรวจสอบการเข้าถึง',
    'ห้องสมุดไม่ได้สมัครสมาชิก',
    'ไม่มีข้อมูลการเข้าสู่ระบบ',
    'ห้องสมุดของคุณไม่ได้สมัครทรัพยากรออนไลน์นี้ คลิกลิงก์ด้านล่างเพื่อแนะนำให้จัดซื้อ',
    'แนะนำให้จัดซื้อ',
    'บัญชีของคุณต้องได้รับการดูแลก่อนจึงจะแสดงข้อมูลการเข้าสู่ระบบได้ โปรดเขียนถึง %s เพื่อขอความช่วยเหลือ',
  ],
  'zh-Hans-CN': [
    '登录以检查访问权限',
    '图书馆未订阅',
    '登录信息不可用',
    '您的图书馆未订阅此在线资源。请点击下方链接建议采购。',
    '建议采购',
    '您的账户需要处理后才能显示登录信息。请写信至 %s 寻求帮助。',
  ],
  'zh-Hant-TW': [
    '登入以檢查存取權',
    '圖書館未訂閱',
    '登入資訊不可用',
    '您的圖書館未訂閱此線上資源。請點選下方連結建議採購。',
    '建議採購',
    '您的帳戶需要處理後才能顯示登入資訊。請寫信至 %s 尋求協助。',
  ],
  'zh-CN': [
    '登录以检查访问权限',
    '图书馆未订阅',
    '登录信息不可用',
    '您的图书馆未订阅此在线资源。请点击下方链接建议采购。',
    '建议采购',
    '您的账户需要处理后才能显示登录信息。请写信至 %s 寻求帮助。',
  ],
  'zh-TW': [
    '登入以檢查存取權',
    '圖書館未訂閱',
    '登入資訊不可用',
    '您的圖書館未訂閱此線上資源。請點選下方連結建議採購。',
    '建議採購',
    '您的帳戶需要處理後才能顯示登入資訊。請寫信至 %s 尋求協助。',
  ],
  'ca-ES': [
    'Inicia sessió per comprovar l\'accés',
    'Biblioteca no subscrita',
    'Informació d\'inici de sessió no disponible',
    'La vostra biblioteca no està subscrita a aquest recurs en línia. Feu clic a l\'enllaç següent per suggerir-ne la compra.',
    'Suggerir per a la compra',
    'El vostre compte requereix atenció abans que es pugui mostrar la informació d\'inici de sessió. Escriviu a %s per obtenir ajuda.',
  ],
  'cs-CZ': [
    'Přihlaste se pro ověření přístupu',
    'Knihovna není předplatitel',
    'Přihlašovací údaje nejsou k dispozici',
    'Vaše knihovna nemá předplacený tento online zdroj. Klikněte na odkaz níže a navrhněte jeho nákup.',
    'Navrhnout k nákupu',
    'Váš účet vyžaduje pozornost, než lze zobrazit přihlašovací údaje. Napište na %s pro pomoc.',
  ],
  'da-DK': [
    'Log ind for at tjekke adgang',
    'Biblioteket abonnerer ikke',
    'Loginoplysninger ikke tilgængelige',
    'Dit bibliotek abonnerer ikke på denne online ressource. Klik på linket nedenfor for at foreslå køb.',
    'Foreslå til køb',
    'Din konto kræver opmærksomhed, før loginoplysninger kan vises. Skriv til %s for hjælp.',
  ],
  'es-ES': [
    'Iniciar sesión para comprobar el acceso',
    'Biblioteca no suscrita',
    'Información de acceso no disponible',
    'Su biblioteca no está suscrita a este recurso en línea. Haga clic en el enlace siguiente para sugerir su compra.',
    'Sugerir para compra',
    'Su cuenta requiere atención antes de que se pueda mostrar la información de acceso. Escriba a %s para obtener ayuda.',
  ],
  'fi-FI': [
    'Kirjaudu sisään tarkistaaksesi käyttöoikeuden',
    'Kirjasto ei ole tilaaja',
    'Kirjautumistiedot eivät ole saatavilla',
    'Kirjastosi ei ole tilannut tätä verkkoresurssia. Napsauta alla olevaa linkkiä ehdottaaksesi hankintaa.',
    'Ehdota hankittavaksi',
    'Tilisi vaatii huomiota ennen kuin kirjautumistiedot voidaan näyttää. Kirjoita osoitteeseen %s saadaksesi apua.',
  ],
  'fr-CA': [
    'Se connecter pour vérifier l\'accès',
    'Bibliothèque non abonnée',
    'Informations de connexion non disponibles',
    'Votre bibliothèque n\'est pas abonnée à cette ressource en ligne. Cliquez sur le lien ci-dessous pour la suggérer à l\'achat.',
    'Suggestion d\'achat',
    'Votre compte nécessite une attention avant que les informations de connexion puissent être affichées. Veuillez écrire à %s pour obtenir de l\'aide.',
  ],
  'gl-ES': [
    'Iniciar sesión para comprobar o acceso',
    'Biblioteca non subscrita',
    'Información de acceso non dispoñible',
    'A súa biblioteca non está subscrita a este recurso en liña. Prema na ligazón de abaixo para suxerir a súa compra.',
    'Suxerir para compra',
    'A súa conta require atención antes de que se poida mostrar a información de acceso. Escriba a %s para obter axuda.',
  ],
  'hr-HR': [
    'Prijavite se za provjeru pristupa',
    'Knjižnica nije pretplatnik',
    'Podaci za prijavu nisu dostupni',
    'Vaša knjižnica nije pretplaćena na ovaj mrežni resurs. Kliknite poveznicu ispod kako biste predložili nabavu.',
    'Predloži za nabavu',
    'Vaš račun zahtijeva pažnju prije nego što se mogu prikazati podaci za prijavu. Pišite na %s za pomoć.',
  ],
  'hu-HU': [
    'Jelentkezzen be a hozzáférés ellenőrzéséhez',
    'A könyvtár nem előfizető',
    'A bejelentkezési adatok nem érhetők el',
    'Könyvtára nem fizet elő erre az online forrásra. Kattintson az alábbi linkre a beszerzés javaslatához.',
    'Javaslat beszerzésre',
    'Fiókját rendezni kell, mielőtt a bejelentkezési adatok megjeleníthetők. Írjon a %s címre segítségért.',
  ],
  'it-IT': [
    'Accedi per verificare l\'accesso',
    'Biblioteca non abbonata',
    'Informazioni di accesso non disponibili',
    'La tua biblioteca non è abbonata a questa risorsa online. Fai clic sul link qui sotto per suggerirne l\'acquisto.',
    'Suggerisci per l\'acquisto',
    'Il tuo account richiede attenzione prima che le informazioni di accesso possano essere mostrate. Scrivi a %s per assistenza.',
  ],
  'nb-NO': [
    'Logg inn for å sjekke tilgang',
    'Biblioteket abonnerer ikke',
    'Innloggingsinfo ikke tilgjengelig',
    'Biblioteket ditt abonnerer ikke på denne nettressursen. Klikk lenken nedenfor for å foreslå kjøp.',
    'Foreslå til kjøp',
    'Kontoen din krever oppmerksomhet før innloggingsinfo kan vises. Skriv til %s for hjelp.',
  ],
  'nn-NO': [
    'Logg inn for å sjekke tilgang',
    'Biblioteket abonnerer ikkje',
    'Innloggingsinfo ikkje tilgjengeleg',
    'Biblioteket ditt abonnerer ikkje på denne nettressursen. Klikk lenkja under for å foreslå kjøp.',
    'Foreslå til kjøp',
    'Kontoen din krev oppmerksomheit før innloggingsinfo kan visast. Skriv til %s for hjelp.',
  ],
  'nl-BE': [
    'Aanmelden om toegang te controleren',
    'Bibliotheek niet geabonneerd',
    'Inloggegevens niet beschikbaar',
    'Uw bibliotheek is niet geabonneerd op deze online bron. Klik op de onderstaande link om aan te schaffen voor te stellen.',
    'Voorstellen om aan te schaffen',
    'Uw account vereist aandacht voordat de inloggegevens kunnen worden getoond. Schrijf naar %s voor hulp.',
  ],
  'nl-NL': [
    'Aanmelden om toegang te controleren',
    'Bibliotheek niet geabonneerd',
    'Inloggegevens niet beschikbaar',
    'Uw bibliotheek is niet geabonneerd op deze online bron. Klik op de onderstaande link om aan te schaffen voor te stellen.',
    'Voorstellen om aan te schaffen',
    'Uw account vereist aandacht voordat de inloggegevens kunnen worden getoond. Schrijf naar %s voor hulp.',
  ],
  'pl-PL': [
    'Zaloguj się, aby sprawdzić dostęp',
    'Biblioteka nie subskrybuje',
    'Informacje logowania niedostępne',
    'Twoja biblioteka nie subskrybuje tego zasobu online. Kliknij poniższy link, aby zaproponować zakup.',
    'Zaproponuj zakup',
    'Twoje konto wymaga uwagi, zanim można wyświetlić informacje logowania. Napisz na %s po pomoc.',
  ],
  'pt-BR': [
    'Entrar para verificar o acesso',
    'Biblioteca não assinante',
    'Informações de login indisponíveis',
    'Sua biblioteca não assina este recurso online. Clique no link abaixo para sugerir a compra.',
    'Sugerir para compra',
    'Sua conta precisa de atenção antes que as informações de login possam ser exibidas. Escreva para %s para obter ajuda.',
  ],
  'pt-PT': [
    'Iniciar sessão para verificar o acesso',
    'Biblioteca não subscrita',
    'Informações de login indisponíveis',
    'A sua biblioteca não subscreve este recurso online. Clique na ligação abaixo para sugerir a compra.',
    'Sugerir para compra',
    'A sua conta requer atenção antes de as informações de login poderem ser mostradas. Escreva para %s para obter ajuda.',
  ],
  'ro-RO': [
    'Conectați-vă pentru a verifica accesul',
    'Biblioteca nu este abonată',
    'Informațiile de conectare nu sunt disponibile',
    'Biblioteca dvs. nu este abonată la această resursă online. Faceți clic pe linkul de mai jos pentru a sugera achiziția.',
    'Sugerați pentru achiziție',
    'Contul dvs. necesită atenție înainte ca informațiile de conectare să poată fi afișate. Scrieți la %s pentru ajutor.',
  ],
  'ru-RU': [
    'Войдите, чтобы проверить доступ',
    'Библиотека не подписана',
    'Данные для входа недоступны',
    'Ваша библиотека не подписана на этот онлайн-ресурс. Нажмите ссылку ниже, чтобы предложить покупку.',
    'Предложить к покупке',
    'Ваша учётная запись требует внимания, прежде чем можно показать данные для входа. Напишите на %s за помощью.',
  ],
  'sk-SK': [
    'Prihláste sa na overenie prístupu',
    'Knižnica nie je predplatiteľ',
    'Prihlasovacie údaje nie sú k dispozícii',
    'Vaša knižnica nemá predplatený tento online zdroj. Kliknite na odkaz nižšie a navrhnite jeho nákup.',
    'Navrhnúť na nákup',
    'Váš účet vyžaduje pozornosť, kým možno zobraziť prihlasovacie údaje. Napíšte na %s o pomoc.',
  ],
  'sl-SI': [
    'Prijavite se za preverjanje dostopa',
    'Knjižnica ni naročnik',
    'Podatki za prijavo niso na voljo',
    'Vaša knjižnica ni naročena na ta spletni vir. Kliknite spodnjo povezavo, da predlagate nakup.',
    'Predlagaj za nakup',
    'Vaš račun zahteva pozornost, preden je mogoče prikazati podatke za prijavo. Pišite na %s za pomoč.',
  ],
  'sv-SE': [
    'Logga in för att kontrollera åtkomst',
    'Biblioteket prenumererar inte',
    'Inloggningsinfo inte tillgänglig',
    'Ditt bibliotek prenumererar inte på denna onlineresurs. Klicka på länken nedan för att föreslå inköp.',
    'Föreslå för inköp',
    'Ditt konto kräver uppmärksamhet innan inloggningsinfo kan visas. Skriv till %s för hjälp.',
  ],
  'tr-TR': [
    'Erişimi kontrol etmek için giriş yapın',
    'Kütüphane abone değil',
    'Giriş bilgileri kullanılamıyor',
    'Kütüphaneniz bu çevrimiçi kaynağa abone değil. Satın alma önermek için aşağıdaki bağlantıya tıklayın.',
    'Satın alma için öner',
    'Giriş bilgileri gösterilmeden önce hesabınızın ilgilenilmesi gerekir. Yardım için %s adresine yazın.',
  ],
  'uk-UA': [
    'Увійдіть, щоб перевірити доступ',
    'Бібліотека не підписана',
    'Дані для входу недоступні',
    'Ваша бібліотека не підписана на цей онлайн-ресурс. Натисніть посилання нижче, щоб запропонувати закупівлю.',
    'Запропонувати до закупівлі',
    'Ваш обліковий запис потребує уваги, перш ніж можна показати дані для входу. Напишіть на %s за допомогою.',
  ],
  'cy-GB': [
    'Mewngofnodi i wirio mynediad',
    'Nid yw\'r llyfrgell yn tanysgrifio',
    'Nid yw gwybodaeth mewngofnodi ar gael',
    'Nid yw eich llyfrgell yn tanysgrifio i\'r adnodd ar-lein hwn. Cliciwch y ddolen isod i awgrymu ei brynu.',
    'Awgrymu ar gyfer prynu',
    'Mae angen sylw ar eich cyfrif cyn y gellir dangos gwybodaeth mewngofnodi. Ysgrifennwch at %s am gymorth.',
  ],
  'is-IS': [
    'Skráðu þig inn til að athuga aðgang',
    'Bókasafnið á ekki áskrift',
    'Innskráningarupplýsingar ekki tiltækar',
    'Bókasafnið þitt á ekki áskrift að þessum netauðlind. Smelltu á tengilinn hér að neðan til að leggja til kaup.',
    'Leggja til kaup',
    'Reikningurinn þinn þarf athygli áður en hægt er að sýna innskráningarupplýsingar. Skrifaðu til %s til að fá aðstoð.',
  ],
  ar: [
    'سجّل الدخول للتحقق من الوصول',
    'المكتبة غير مشتركة',
    'معلومات تسجيل الدخول غير متاحة',
    'مكتبتك غير مشتركة في هذا المورد عبر الإنترنت. انقر الرابط أدناه لاقتراح شرائه.',
    'اقترح للشراء',
    'يتطلب حسابك اهتماماً قبل عرض معلومات تسجيل الدخول. يرجى الكتابة إلى %s للمساعدة.',
  ],
  'el-GR': [
    'Συνδεθείτε για έλεγχο πρόσβασης',
    'Η βιβλιοθήκη δεν είναι συνδρομήτρια',
    'Οι πληροφορίες σύνδεσης δεν είναι διαθέσιμες',
    'Η βιβλιοθήκη σας δεν είναι συνδρομήτρια σε αυτόν τον διαδικτυακό πόρο. Κάντε κλικ στον παρακάτω σύνδεσμο για να προτείνετε αγορά.',
    'Πρόταση για αγορά',
    'Ο λογαριασμός σας χρειάζεται προσοχή πριν εμφανιστούν οι πληροφορίες σύνδεσης. Γράψτε στο %s για βοήθεια.',
  ],
  'he-IL': [
    'התחבר כדי לבדוק גישה',
    'הספרייה אינה מנויה',
    'פרטי ההתחברות אינם זמינים',
    'הספרייה שלך אינה מנויה למשאב מקוון זה. לחץ על הקישור למטה כדי להציע רכישה.',
    'הצע לרכישה',
    'החשבון שלך דורש טיפול לפני שניתן להציג את פרטי ההתחברות. כתוב ל-%s לעזרה.',
  ],
  'ja-JP': [
    'ログインしてアクセスを確認',
    '図書館は未契約です',
    'ログイン情報は利用できません',
    'お使いの図書館はこのオンラインリソースを契約していません。下のリンクをクリックして購入を提案してください。',
    '購入を提案',
    'ログイン情報を表示する前にアカウントへの対応が必要です。%s までお問い合わせください。',
  ],
  'ko-KR': [
    '로그인하여 액세스 확인',
    '도서관이 구독하지 않음',
    '로그인 정보를 사용할 수 없음',
    '귀하의 도서관은 이 온라인 자료를 구독하지 않습니다. 아래 링크를 클릭하여 구매를 제안하세요.',
    '구매 제안',
    '로그인 정보를 표시하기 전에 계정 조치가 필요합니다. 도움이 필요하면 %s(으)로 문의하세요.',
  ],
  'et-EE': [
    'Logige sisse juurdepääsu kontrollimiseks',
    'Raamatukogu ei telli',
    'Sisselogimisandmed pole saadaval',
    'Teie raamatukogu ei telli seda veebiressurssi. Klõpsake allolevat linki, et soovitada ostu.',
    'Soovita ostmiseks',
    'Teie konto vajab tähelepanu enne sisselogimisandmete kuvamist. Kirjutage abi saamiseks aadressile %s.',
  ],
  'lv-LV': [
    'Piesakieties, lai pārbaudītu piekļuvi',
    'Bibliotēka nav abonente',
    'Pieteikšanās informācija nav pieejama',
    'Jūsu bibliotēka nav abonējusi šo tiešsaistes resursu. Noklikšķiniet uz zemāk esošās saites, lai ieteiktu iegādi.',
    'Ieteikt iegādei',
    'Jūsu kontam nepieciešama uzmanība, pirms var parādīt pieteikšanās informāciju. Rakstiet uz %s, lai saņemtu palīdzību.',
  ],
  'bg-BG': [
    'Влезте, за да проверите достъпа',
    'Библиотеката не е абонат',
    'Информацията за вход не е налична',
    'Вашата библиотека не е абонирана за този онлайн ресурс. Щракнете върху връзката по-долу, за да предложите покупка.',
    'Предложи за покупка',
    'Вашият акаунт изисква внимание, преди да може да се покаже информацията за вход. Пишете на %s за помощ.',
  ],
  'sr-RS': [
    'Пријавите се да проверите приступ',
    'Библиотека није претплатник',
    'Подаци за пријаву нису доступни',
    'Ваша библиотека није претплаћена на овај мрежни ресурс. Кликните на везу испод да предложите набавку.',
    'Предложи за набавку',
    'Ваш налог захтева пажњу пре него што се могу приказати подаци за пријаву. Пишите на %s за помоћ.',
  ],
  'fo-FO': [
    'Rita inn fyri at kanna atgongd',
    'Bókasavnið hevur ikki áskrift',
    'Innritanarupplýsingar ikki tøkar',
    'Títt bókasavn hevur ikki áskrift til hesa netútbúgvingina. Trýst á leinkjuna niðanfyri fyri at leggja til keyp.',
    'Legg til keyp',
    'Tín konto krevur umsorgan áðrenn innritanarupplýsingar kunnu vísast. Skriva til %s fyri hjálp.',
  ],
  eu: [
    'Hasi saioa sarbidea egiaztatzeko',
    'Liburutegiak ez du harpidetza',
    'Saioa hasteko informazioa ez dago erabilgarri',
    'Zure liburutegiak ez du lineako baliabide hau harpidetuta. Egin klik beheko estekan erosketa iradokitzeko.',
    'Iradoki erosketa',
    'Zure kontuak arreta behar du saioa hasteko informazioa erakutsi aurretik. Idatzi %s helbidera laguntza lortzeko.',
  ],
};

function main() {
  const catalogs = JSON.parse(fs.readFileSync(catalogsPath, 'utf8'));
  let patched = 0;

  for (const locale of Object.keys(catalogs)) {
    const msgstrs = LOCALE_MSGSTRS[locale];
    if (!msgstrs || msgstrs.length !== OPAC_ACCESS_STATE_MSGIDS.length) {
      throw new Error(`Missing translations for locale ${locale}`);
    }
    for (let i = 0; i < OPAC_ACCESS_STATE_MSGIDS.length; i++) {
      const msgid = OPAC_ACCESS_STATE_MSGIDS[i];
      catalogs[locale][msgid] = msgstrs[i];
    }
    patched++;
  }

  fs.writeFileSync(catalogsPath, JSON.stringify(catalogs, null, 2) + '\n', 'utf8');
  console.log(`Patched ${patched} locale(s) in ${catalogsPath}`);
  console.log(`Added ${OPAC_ACCESS_STATE_MSGIDS.length} msgid(s) each`);
}

main();

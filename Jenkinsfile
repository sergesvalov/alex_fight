pipeline {
    agent { label 'built-in' } // Для старых версий Jenkins (до 2.319) используйте label 'master'
    
    options {
        timeout(time: 1, unit: 'HOURS')
        // Checkout делается вручную в 'Source Checkout' - перед ним нужно успеть вернуть себе
        // права на файлы рабочей директории (см. комментарий там).
        skipDefaultCheckout()
    }

    parameters {
        booleanParam(name: 'RUN_TESTS', defaultValue: true, description: 'Запускать ли автотесты Godot перед сборкой')
        booleanParam(name: 'BUILD_ANDROID', defaultValue: true, description: 'Собирать ли APK для Android (Phone и Quest 2)')
        booleanParam(name: 'BUILD_MAC', defaultValue: false, description: 'Собирать ли версию для macOS')
        booleanParam(name: 'BUILD_WINDOWS', defaultValue: true, description: 'Собирать ли версию для ПК (Windows)')
    }

    environment {
        // Конфигурация локального реестра
        REGISTRY_IP   = "192.168.0.222"
        REGISTRY_PORT = "5050"

        // Имя образа для Godot-сборщика (x86_64)
        BUILDER_IMAGE = "${REGISTRY_IP}:${REGISTRY_PORT}/alex-fight-godot-builder"
    }

    stages {
        stage('Source Checkout') {
            steps {
                // Сборка идёт в контейнере под root (inside('-u root') ниже), поэтому всё, что
                // она создаёт в рабочей директории (.godot/, build/, *.import, *.uid), принадлежит
                // root. Стоит git-плагину решить пересоздать директорию (свежий clone) - он падает
                // с "Failed to clean the workspace: Unable to delete", потому что пользователь
                // jenkins не может удалить чужие файлы. Возвращаем владельца тем же способом,
                // каким он был потерян - через контейнер под root. '|| true': на самой первой
                // сборке директории ещё может не быть.
                sh 'docker run --rm -v "$WORKSPACE":/ws alpine chown -R "$(id -u):$(id -g)" /ws || true'
                checkout scm
            }
        }

        stage('Build & Push Builder Image') {
            steps {
                script {
                    // project.godot's config/features tag only ever carries "major.minor" (e.g. "4.7"),
                    // never the patch version - Godot doesn't encode patch releases in that tag at all.
                    // So the exact engine build is pinned here directly instead of parsed from the project.
                    env.GODOT_VERSION = '4.7.2'
                    echo "Требуемая версия Godot: ${env.GODOT_VERSION}"
                    echo "Сборка Docker-образа Godot ${env.GODOT_VERSION} (x86_64) + Android SDK..."
                    sh "docker build --build-arg GODOT_VERSION=${env.GODOT_VERSION} -t ${BUILDER_IMAGE}:${env.GODOT_VERSION} -f Dockerfile.android ."
                    
                    echo "Пушим сборочный образ в локальный реестр..."
                    // Реестр - только кэш образа для других агентов: сама сборка ниже берёт образ,
                    // который docker build только что положил локально. Поэтому отказ реестра
                    // (например "blob upload unknown to registry" - реестр потерял сессию загрузки
                    // слоя) не должен ронять сборку игры: три попытки, затем предупреждение.
                    sh """
                    for attempt in 1 2 3; do
                        if docker push ${BUILDER_IMAGE}:${env.GODOT_VERSION}; then
                            exit 0
                        fi
                        echo "docker push не удался (попытка \$attempt из 3)"
                        sleep 5
                    done
                    echo 'ПРЕДУПРЕЖДЕНИЕ: образ не отправлен в реестр, сборка продолжается с локальным образом.'
                    """
                }
            }
        }

        stage('Compile Godot Builds') {
            steps {
                script {
                    echo "Запускаем процесс компиляции внутри Godot-образа..."
                    
                    // Запускаем контейнер из только что собранного образа
                    // Именованный том для /root/.gradle: без него дистрибутив gradle и все зависимости
                    // Android-сборки скачиваются заново при каждом прогоне (контейнер одноразовый).
                    docker.image("${BUILDER_IMAGE}:${env.GODOT_VERSION}").inside('-u root -v alex-fight-gradle-cache:/root/.gradle') {
                        
                        // --- Prepare Version ---
                        echo "Обновляем номер сборки в export_presets.cfg..."
                        sh "if [ -f export_presets.cfg ]; then sed -i -E 's/version\\/code=[0-9]+/version\\/code=${env.BUILD_NUMBER}/' export_presets.cfg; fi"
                        sh "if [ -f export_presets.cfg ]; then sed -i -E \"s/version\\/name=\\\".*\\\"/version\\/name=\\\"1.0.${env.BUILD_NUMBER}\\\"/\" export_presets.cfg; fi"

                        // --- Clean stale Godot cache ---
                        // Jenkins переиспользует одну и ту же рабочую директорию между сборками
                        // (cleanWs() нигде не вызывается) - checkout scm обновляет отслеживаемые
                        // git-файлы, но НЕ трогает .godot/ (в .gitignore), включая uid_cache.bin
                        // и кэш импорта. Обнаружено 2026-08-23: сборка с подтверждённо верным
                        // исходником в git и успешным (exit 0) --export-release всё равно
                        // упаковывала устаревшее содержимое одной конкретной сцены
                        // (elevator_shaft.tscn) - единственное объяснение: устаревший кэш
                        // ресурсов от предыдущей сборки на том же агенте. Полная чистка перед
                        // каждым импортом/экспортом устраняет этот класс бага целиком.
                        echo "Удаляем кэш .godot/ от предыдущей сборки (если остался)..."
                        sh "rm -rf .godot"

                        // --- Import Assets ---
                        echo "Подготовка дефолтного конфига для импорта и тестов (PC)..."
                        sh "cp configs/project.pc.godot project.godot"
                        echo "Импорт ассетов Godot (создание кэша .godot/)..."
                        sh "if [ -f project.godot ]; then godot --headless --editor --quit || true; fi"

                        echo "Проверка успешности импорта текстур..."
                        sh "ls -la .godot/imported/ || echo 'Каталог .godot/imported не найден!'"
                        sh '''
                        if ! ls .godot/imported/hotel_carpet*.ctex 1> /dev/null 2>&1; then
                            echo "ОШИБКА: Текстура ковра не была импортирована!"
                            exit 1
                        fi
                        if ! ls .godot/imported/hotel_wallpaper*.ctex 1> /dev/null 2>&1; then
                            echo "ОШИБКА: Текстура обоев не была импортирована!"
                            exit 1
                        fi
                        echo "Текстуры успешно импортированы движком!"
                        '''
                        sh "mkdir -p build"

                        stage('Run Autotests') {
                            if (params.RUN_TESTS) {
                                echo "Запуск headless автотестов Godot..."
                                // tools/run_tests.sh прогоняет все tests/*.tscn и считает сцену
                                // проваленной не только по коду возврата, но и по "SCRIPT ERROR" в
                                // логе: скрипт, который не компилируется, оставляет сцену с кодом 0.
                                sh 'TEST_TIMEOUT=600 bash tools/run_tests.sh'
                            } else {
                                echo "Автотесты пропущены (RUN_TESTS = false)"
                            }
                        }

                        stage('Build & Sign Android APKs') {
                            if (params.BUILD_ANDROID) {
                                echo "Запуск экспорта и подписи Android-проектов (Phone & VR)..."
                                // Release-подпись: keystore и пароль лежат в Jenkins credentials
                                //   alex-fight-release-keystore       (Secret file)
                                //   alex-fight-release-keystore-pass  (Secret text)
                                // Пока их нет, сборка подписывается debug-ключом, как раньше.
                                // Наличие проверяется отдельным пустым withCredentials, чтобы
                                // try/catch не проглотил ошибку самой сборки.
                                def releaseCreds = [
                                    file(credentialsId: 'alex-fight-release-keystore', variable: 'RELEASE_KEYSTORE'),
                                    string(credentialsId: 'alex-fight-release-keystore-pass', variable: 'RELEASE_KEYSTORE_PASS')
                                ]
                                def haveReleaseCreds = false
                                try {
                                    withCredentials(releaseCreds) { haveReleaseCreds = true }
                                } catch (err) {
                                    echo "Release-ключ в Jenkins credentials не найден - APK будут подписаны debug-ключом."
                                }
                                def buildAndroid = {
                                sh '''
                                sign_apk() {
                                    APK_PATH=$1
                                    if [ -f "$APK_PATH" ]; then
                                        # RELEASE_KEYSTORE / RELEASE_KEYSTORE_PASS приходят из Jenkins
                                        # credentials (см. withCredentials ниже); пароль читает сам
                                        # apksigner из окружения, в лог он не попадает.
                                        if [ -n "${RELEASE_KEYSTORE:-}" ] && [ -f "$RELEASE_KEYSTORE" ]; then
                                            echo "Подписываем $APK_PATH release-ключом..."
                                            zipalign -p 4 "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                            apksigner sign --ks "$RELEASE_KEYSTORE" --ks-pass env:RELEASE_KEYSTORE_PASS --out "${APK_PATH%.apk}-release.apk" "${APK_PATH%.apk}-aligned.apk"
                                            rm "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                            # Переименовываем обратно, чтобы архив Jenkins корректно подхватил файлы
                                            mv "${APK_PATH%.apk}-release.apk" "$APK_PATH"
                                        else
                                            echo "Release-ключ не задан. Выполняем подпись с помощью debug.keystore для $APK_PATH..."
                                            if [ ! -f "debug.keystore" ]; then
                                                echo "Генерируем временный debug.keystore..."
                                                keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
                                            fi
                                            zipalign -p 4 "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                            apksigner sign --ks debug.keystore --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android --out "${APK_PATH%.apk}-signed.apk" "${APK_PATH%.apk}-aligned.apk"
                                            rm "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                            mv "${APK_PATH%.apk}-signed.apk" "$APK_PATH"
                                        fi
                                    fi
                                }

                                # Экспорт без "|| true": код возврата и лог сохраняются. Сборка падает,
                                # если файла нет; ненулевой код при готовом файле - предупреждение с
                                # хвостом лога (Godot возвращает его и по безобидным поводам вроде
                                # недоступного adb). Файл от ПРЕДЫДУЩЕЙ сборки удаляется заранее -
                                # build/ между прогонами не чистится, и без этого упавший экспорт
                                # выглядел бы успешным.
                                run_export() {
                                    PRESET=$1; OUT=$2; LOG=$3; shift 3
                                    rm -f "$OUT"
                                    set +e
                                    godot --headless "$@" --export-release "$PRESET" "$OUT" > "$LOG" 2>&1
                                    EXPORT_CODE=$?
                                    set -e
                                    if [ ! -f "$OUT" ]; then
                                        tail -n 80 "$LOG"
                                        echo "ЭКСПОРТ '$PRESET' ПРОВАЛЕН: $OUT не создан (код возврата $EXPORT_CODE)"
                                        return 1
                                    fi
                                    if [ "$EXPORT_CODE" -ne 0 ]; then
                                        tail -n 30 "$LOG"
                                        echo "ПРЕДУПРЕЖДЕНИЕ: экспорт '$PRESET' вернул код $EXPORT_CODE, но $OUT создан."
                                    fi
                                    grep -E 'ERROR|SCRIPT ERROR' "$LOG" | head -n 20 || true
                                    return 0
                                }

                                if grep -q 'name="Android"' export_presets.cfg 2>/dev/null; then
                                    echo "Копируем конфиг телефона..."
                                    cp configs/project.phone.godot project.godot
                                    run_export "Android" build/alex_fight.apk build/android_export.log
                                    echo "Подписываем build/alex_fight.apk..."
                                    sign_apk "build/alex_fight.apk"
                                else
                                    echo "Пресет Android не найден в export_presets.cfg. Сборка обычного APK пропущена."
                                fi

                                if grep -q 'name="Android Quest 2"' export_presets.cfg 2>/dev/null; then
                                    echo "Копируем конфиг VR..."
                                    cp configs/project.vr.godot project.godot
                                    echo "Запуск автотеста конфигурации VR..."
                                    godot --headless -s tests/verify_vr_config.gd || { echo 'VR CONFIG TEST FAILED!'; exit 1; }
                                    # OpenXR в Godot 4.7 экспортируется только gradle-сборкой
                                    # (gradle_build/use_gradle_build в пресете), а ей нужен шаблон
                                    # сборки в res://android/build - его ставит
                                    # --install-android-build-template. Лог сохраняем: без него
                                    # упавший gradle выглядит просто как "apk не появился".
                                    #
                                    # Шаблон сборки Godot задаёт gradle-демону свою (большую) кучу в
                                    # android/build/gradle.properties. Сборка от 2026-10-08 упала
                                    # на dexBuilderStandardRelease с "Gradle build daemon
                                    # disappeared unexpectedly" - демона убили извне, так обычно
                                    # выглядит OOM-killer (не подтверждено: для этого ниже печать
                                    # памяти и memory.events). gradle.properties из GRADLE_USER_HOME
                                    # имеет приоритет над проектным, поэтому ужимаем кучу здесь, а
                                    # не правим шаблон, который Godot перезаписывает при установке.
                                    mkdir -p "$HOME/.gradle"
                                    cat > "$HOME/.gradle/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError
org.gradle.workers.max=2
org.gradle.daemon=false
EOF
                                    echo "Память перед gradle-сборкой:"
                                    grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' /proc/meminfo || true
                                    if ! run_export "Android Quest 2" build/alex_fight_vr.apk build/vr_export.log --install-android-build-template; then
                                        # Отличаем OOM-killer (oom_kill > 0) от падения самой JVM (hs_err).
                                        echo "Память после падения:"
                                        grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' /proc/meminfo || true
                                        echo "cgroup memory.events:"; cat /sys/fs/cgroup/memory.events 2>/dev/null || true
                                        ls -la android/build/hs_err_pid*.log hs_err_pid*.log 2>/dev/null || true
                                        exit 1
                                    fi
                                    echo "Подписываем build/alex_fight_vr.apk..."
                                    sign_apk "build/alex_fight_vr.apk"
                                else
                                    echo "Пресет Android Quest 2 не найден в export_presets.cfg. Сборка VR APK пропущена."
                                fi
                                '''
                                }
                                if (haveReleaseCreds) {
                                    withCredentials(releaseCreds) { buildAndroid() }
                                } else {
                                    buildAndroid()
                                }
                            } else {
                                echo "Сборка и подпись Android APK пропущены (BUILD_ANDROID = false)"
                            }
                        }

                        stage('Build PC (Windows)') {
                            if (params.BUILD_WINDOWS) {
                                echo "Запуск экспорта Windows-проекта для теста..."
                                sh '''
                                REPORT="build/windows_build_report.txt"
                                mkdir -p build
                                {
                                    echo "=== Случай в гостинице «Сибирь» - отчёт о сборке Windows ==="
                                    echo "Jenkins build: #${BUILD_NUMBER}"
                                    # git сам по себе не установлен в образе сборщика (см.
                                    # Dockerfile.android) - используем переменную окружения,
                                    # которую checkout scm уже выставил, вместо git rev-parse.
                                    echo "Git commit: ${GIT_COMMIT:-неизвестен}"
                                    echo "Дата (UTC): $(date -u '+%Y-%m-%d %H:%M:%S')"
                                    echo ""
                                } > "$REPORT"

                                if grep -q 'name="Windows Desktop"' export_presets.cfg 2>/dev/null; then
                                    echo "Копируем конфиг ПК..."
                                    cp configs/project.pc.godot project.godot

                                    # Полная чистка перед экспортом - без этого файл от ПРЕДЫДУЩЕЙ
                                    # сборки мог бы остаться в build/windows и пройти проверку
                                    # "файл существует" ниже, даже если сам export-release в этот
                                    # раз реально провалился (тем более что || true глушит его код
                                    # возврата) - именно так тестировался бы устаревший .exe
                                    # незаметно для CI, при этом выглядя "успешной" сборкой.
                                    rm -rf build/windows
                                    mkdir -p build/windows

                                    EXPORT_LOG="build/windows_export.log"
                                    set +e
                                    godot --headless --export-release "Windows Desktop" build/windows/alex_fight.exe > "$EXPORT_LOG" 2>&1
                                    EXPORT_EXIT_CODE=$?
                                    set -e

                                    {
                                        echo "Код возврата godot --export-release: $EXPORT_EXIT_CODE"
                                        echo ""
                                        echo "--- Ошибки/предупреждения из вывода Godot ---"
                                        grep -iE 'error|ошибка|failed|warning' "$EXPORT_LOG" || echo "(не найдено)"
                                        echo ""
                                    } >> "$REPORT"

                                    if [ -f "build/windows/alex_fight.exe" ]; then
                                        {
                                            echo "Статус: УСПЕХ"
                                            echo "Файл: build/windows/alex_fight.exe"
                                            echo "Размер: $(stat -c%s build/windows/alex_fight.exe 2>/dev/null || echo '?') байт"
                                            echo "Время создания (UTC): $(date -u -r build/windows/alex_fight.exe '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '?')"
                                        } >> "$REPORT"
                                    else
                                        echo "Статус: ОШИБКА - build/windows/alex_fight.exe не создан" >> "$REPORT"
                                        cat "$REPORT"
                                        exit 1
                                    fi

                                    echo "Архивируем сборку ПК в ZIP..."
                                    # zip -r ДОБАВЛЯЕТ/ОБНОВЛЯЕТ существующий архив, а не пересоздаёт
                                    # его с нуля - если alex_fight_pc_test.zip уцелел от предыдущего
                                    # прогона (build/ между сборками не чистится), в свежий архив
                                    # попали бы вперемешку файлы старой сборки, которых в текущей
                                    # build/windows уже нет.
                                    rm -f build/alex_fight_pc_test.zip
                                    cd build/windows && zip -r ../alex_fight_pc_test.zip * && cd ../..
                                else
                                    echo "Статус: ПРОПУЩЕНО - пресет 'Windows Desktop' не найден в export_presets.cfg" >> "$REPORT"
                                fi

                                cat "$REPORT"
                                '''
                            } else {
                                echo "Сборка для Windows пропущена (BUILD_WINDOWS = false)"
                            }
                        }

                        stage('Build Mac (macOS)') {
                            if (params.BUILD_MAC) {
                                echo "Запуск экспорта macOS-проекта..."
                                sh '''
                                if grep -q 'name="macOS"' export_presets.cfg 2>/dev/null; then
                                    echo "Копируем конфиг ПК..."
                                    cp configs/project.pc.godot project.godot
                                    # См. комментарий у Windows-сборки выше ("Build PC (Windows)") -
                                    # тот же риск устаревшего zip от предыдущего прогона Jenkins.
                                    rm -rf build/mac
                                    mkdir -p build/mac
                                    set +e
                                    godot --headless --export-release "macOS" build/mac/alex_fight_mac.zip > build/mac_export.log 2>&1
                                    EXPORT_CODE=$?
                                    set -e
                                    if [ ! -f "build/mac/alex_fight_mac.zip" ]; then
                                        tail -n 80 build/mac_export.log
                                        echo "macOS build failed! (код возврата $EXPORT_CODE)"
                                        exit 1
                                    fi
                                    [ "$EXPORT_CODE" -eq 0 ] || { tail -n 30 build/mac_export.log; echo "ПРЕДУПРЕЖДЕНИЕ: экспорт macOS вернул код $EXPORT_CODE"; }
                                    
                                    echo "Копируем сборку Mac в корень build..."
                                    cp build/mac/alex_fight_mac.zip build/
                                else
                                    echo "Пресет 'macOS' не найден. Сборка под Mac пропущена."
                                fi
                                '''
                            } else {
                                echo "Сборка для macOS пропущена (BUILD_MAC = false)"
                            }
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            // См. 'Source Checkout': после сборки под root возвращаем файлы пользователю jenkins,
            // чтобы рабочую директорию можно было очистить и из самого Jenkins, и следующим checkout.
            sh 'docker run --rm -v "$WORKSPACE":/ws alpine chown -R "$(id -u):$(id -g)" /ws || true'
        }
        success {
            archiveArtifacts artifacts: 'build/*.apk, build/*.zip, build/windows_build_report.txt', fingerprint: true, allowEmptyArchive: true
            echo "Successfully built Случай в гостинице «Сибирь» via Godot Docker Builder! 🎉"
        }
        failure {
            // Отчёт по Windows-сборке архивируется и при падении пайплайна - именно тогда в нём
            // и есть смысл смотреть, на чём и почему сборка сорвалась.
            archiveArtifacts artifacts: 'build/windows_build_report.txt', fingerprint: true, allowEmptyArchive: true
            echo "Failed to build the game. Check logs for errors."
        }
    }
}

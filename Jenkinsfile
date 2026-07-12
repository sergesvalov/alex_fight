pipeline {
    agent { label 'built-in' } // Для старых версий Jenkins (до 2.319) используйте label 'master'
    
    options {
        timeout(time: 1, unit: 'HOURS')
    }

    parameters {
        booleanParam(name: 'RUN_TESTS', defaultValue: false, description: 'Запускать ли автотесты Godot перед сборкой')
        booleanParam(name: 'BUILD_MAC', defaultValue: false, description: 'Собирать ли версию для macOS')
        booleanParam(name: 'BUILD_WINDOWS', defaultValue: true, description: 'Собирать ли версию для ПК (Windows)')
    }

    environment {
        // Конфигурация локального реестра
        REGISTRY_IP   = "192.168.10.222" 
        REGISTRY_PORT = "5050"
        
        // Имя образа для Godot-сборщика (ARM64)
        BUILDER_IMAGE = "${REGISTRY_IP}:${REGISTRY_PORT}/alex-fight-godot-builder"
    }

    stages {
        stage('Source Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build & Push Builder Image') {
            steps {
                script {
                    echo "Определение требуемой версии Godot из project.godot..."
                    env.GODOT_VERSION = sh(script: "grep -oE 'config/features=PackedStringArray\\(\"[0-9]+\\.[0-9]+' project.godot | grep -oE '[0-9]+\\.[0-9]+' || echo '4.7'", returnStdout: true).trim()
                    if (!env.GODOT_VERSION) {
                        // Фолбэк на 4.7
                        env.GODOT_VERSION = '4.7'
                    }
                    
                    echo "Требуемая версия Godot: ${env.GODOT_VERSION}"
                    echo "Сборка Docker-образа Godot ${env.GODOT_VERSION} (ARM64) + Android SDK..."
                    sh "docker build --build-arg GODOT_VERSION=${env.GODOT_VERSION} -t ${BUILDER_IMAGE}:${env.GODOT_VERSION} -f Dockerfile.android ."
                    
                    echo "Пушим сборочный образ в локальный реестр..."
                    sh "docker push ${BUILDER_IMAGE}:${env.GODOT_VERSION}"
                }
            }
        }

        stage('Compile Godot Builds') {
            steps {
                script {
                    echo "Запускаем процесс компиляции внутри Godot-образа..."
                    
                    // Запускаем контейнер из только что собранного образа
                    docker.image("${BUILDER_IMAGE}:${env.GODOT_VERSION}").inside('-u root') {
                        
                        // --- Prepare Version ---
                        echo "Обновляем номер сборки в export_presets.cfg..."
                        sh "if [ -f export_presets.cfg ]; then sed -i -E 's/version\\/code=[0-9]+/version\\/code=${env.BUILD_NUMBER}/' export_presets.cfg; fi"
                        sh "if [ -f export_presets.cfg ]; then sed -i -E \"s/version\\/name=\\\".*\\\"/version\\/name=\\\"1.0.${env.BUILD_NUMBER}\\\"/\" export_presets.cfg; fi"

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
                                sh '''
                                godot --headless tests/test_runner.tscn || {
                                    echo '❌ АВТОТЕСТ МЕНЕДЖЕРА УРОВНЕЙ ПРОВАЛЕН!'
                                    exit 1
                                }
                                godot --headless tests/test_stairs_doors.tscn || {
                                    echo '❌ АВТОТЕСТ ЛЕСТНИЦ И ПРОЕМОВ ПРОВАЛЕН!'
                                    exit 1
                                }
                                godot --headless tests/test_stairs_map.tscn || {
                                    echo '❌ АВТОТЕСТ КАРТЫ ЛЕСТНИЦ ПРОВАЛЕН!'
                                    exit 1
                                }
                                godot --headless tests/test_elevator_alignment.tscn || {
                                    echo '❌ АВТОТЕСТ ВЫРАВНИВАНИЯ ЛИФТА ПРОВАЛЕН!'
                                    exit 1
                                }
                                godot --headless tests/test_north_stairs_border.tscn || {
                                    echo '❌ АВТОТЕСТ ГРАНИЦ СЕВЕРНОЙ ЛЕСТНИЦЫ ПРОВАЛЕН!'
                                    exit 1
                                }
                                godot --headless tests/test_north_stairs_map.tscn || {
                                    echo '❌ АВТОТЕСТ КАРТЫ СЕВЕРНОЙ ЛЕСТНИЦЫ ПРОВАЛЕН!'
                                    exit 1
                                }
                                godot --headless tests/test_north_stairs_side_map.tscn || {
                                    echo '❌ АВТОТЕСТ БОКОВОЙ КАРТЫ СЕВЕРНОЙ ЛЕСТНИЦЫ ПРОВАЛЕН!'
                                    exit 1
                                }
                                echo '✅ ВСЕ АВТОТЕСТЫ ПРОЙДЕНЫ!'
                                '''
                            } else {
                                echo "Автотесты пропущены (RUN_TESTS = false)"
                            }
                        }

                        stage('Build Android APKs') {
                            echo "Запуск экспорта Android-проектов (Phone & VR)..."
                            sh '''
                            if grep -q 'name="Android"' export_presets.cfg 2>/dev/null; then
                                echo "Копируем конфиг телефона..."
                                cp configs/project.phone.godot project.godot
                                godot --headless --export-release "Android" build/alex_fight.apk || true
                                if [ ! -f "build/alex_fight.apk" ]; then echo 'APK build failed!'; exit 1; fi
                            else
                                echo "Пресет Android не найден в export_presets.cfg. Сборка обычного APK пропущена."
                            fi
                            
                            if grep -q 'name="Android Quest 2"' export_presets.cfg 2>/dev/null; then
                                echo "Копируем конфиг VR..."
                                cp configs/project.vr.godot project.godot
                                godot --headless --export-release "Android Quest 2" build/alex_fight_vr.apk || true
                                if [ ! -f "build/alex_fight_vr.apk" ]; then echo 'VR APK build failed!'; exit 1; fi
                            else
                                echo "Пресет Android Quest 2 не найден в export_presets.cfg. Сборка VR APK пропущена."
                            fi
                            '''
                        }
                        
                        stage('Build PC (Windows)') {
                            if (params.BUILD_WINDOWS) {
                                echo "Запуск экспорта Windows-проекта для теста..."
                                sh '''
                                if grep -q 'name="Windows Desktop"' export_presets.cfg 2>/dev/null; then
                                    echo "Копируем конфиг ПК..."
                                    cp configs/project.pc.godot project.godot
                                    mkdir -p build/windows
                                    godot --headless --export-release "Windows Desktop" build/windows/alex_fight.exe || true
                                    if [ ! -f "build/windows/alex_fight.exe" ]; then echo 'Windows build failed!'; exit 1; fi
                                    
                                    echo "Архивируем сборку ПК в ZIP..."
                                    apt-get update && apt-get install -y zip
                                    cd build/windows && zip -r ../alex_fight_pc_test.zip * && cd ../..
                                else
                                    echo "Пресет 'Windows Desktop' не найден. Сборка под ПК пропущена."
                                fi
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
                                    mkdir -p build/mac
                                    godot --headless --export-release "macOS" build/mac/alex_fight_mac.zip || true
                                    if [ ! -f "build/mac/alex_fight_mac.zip" ]; then echo 'macOS build failed!'; exit 1; fi
                                    
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

                        stage('Production Sign (Android)') {
                            echo "Переподписание боевым ключом (если он есть)..."
                            sh '''
                            sign_apk() {
                                APK_PATH=$1
                                if [ -f "$APK_PATH" ]; then
                                    if [ -f "release.keystore" ]; then
                                        zipalign -v -p 4 "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                        apksigner sign --ks release.keystore --ks-pass pass:YOUR_PASSWORD_HERE --out "${APK_PATH%.apk}-release.apk" "${APK_PATH%.apk}-aligned.apk"
                                        rm "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                        # Мы переименовываем обратно, чтобы архив Jenkins корректно подхватил файлы
                                        mv "${APK_PATH%.apk}-release.apk" "$APK_PATH"
                                    else
                                        echo "Файл release.keystore не найден. Выполняем подпись с помощью debug.keystore для $APK_PATH..."
                                        if [ ! -f "debug.keystore" ]; then
                                            echo "Генерируем временный debug.keystore..."
                                            keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
                                        fi
                                        zipalign -v -p 4 "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                        apksigner sign --ks debug.keystore --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android --out "${APK_PATH%.apk}-signed.apk" "${APK_PATH%.apk}-aligned.apk"
                                        rm "$APK_PATH" "${APK_PATH%.apk}-aligned.apk"
                                        mv "${APK_PATH%.apk}-signed.apk" "$APK_PATH"
                                    fi
                                fi
                            }
                            
                            sign_apk "build/alex_fight.apk"
                            sign_apk "build/alex_fight_vr.apk"
                            '''
                        }
                    }
                }
            }
        }
    }

    post {
        success {
            archiveArtifacts artifacts: 'build/*.apk, build/*.zip', fingerprint: true, allowEmptyArchive: true
            echo "Successfully built Alex Fight via Godot Docker Builder! 🎉"
        }
        failure {
            echo "Failed to build the game. Check logs for errors."
        }
    }
}

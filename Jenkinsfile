pipeline {
    agent { label 'built-in' } // Для старых версий Jenkins (до 2.319) используйте label 'master'

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
                        
                        stage('Prepare Version') {
                            echo "Обновляем номер сборки в export_presets.cfg..."
                            sh "if [ -f export_presets.cfg ]; then sed -i -E 's/version\\/code=[0-9]+/version\\/code=${env.BUILD_NUMBER}/' export_presets.cfg; fi"
                            sh "if [ -f export_presets.cfg ]; then sed -i -E \"s/version\\/name=\\\".*\\\"/version\\/name=\\\"1.0.${env.BUILD_NUMBER}\\\"/\" export_presets.cfg; fi"
                        }

                        stage('Import Assets') {
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
                        }

                        stage('Run Autotests') {
                            echo "Запуск headless автотестов Godot..."
                            sh '''
                            godot --headless -s tests/test_runner.gd || {
                                echo '❌ АВТОТЕСТЫ ПРОВАЛЕНЫ!'
                                exit 1
                            }
                            echo '✅ АВТОТЕСТЫ ПРОЙДЕНЫ!'
                            '''
                        }

                        stage('Build Android APK') {
                            echo "Запуск экспорта Android-проекта..."
                            sh '''
                            if grep -q 'name="Android"' export_presets.cfg 2>/dev/null; then
                                godot --headless --export-release "Android" build/alex_fight.apk || true
                                if [ ! -f "build/alex_fight.apk" ]; then echo 'APK build failed!'; exit 1; fi
                            else
                                echo "Пресет Android не найден в export_presets.cfg. Сборка APK пропущена."
                            fi
                            '''
                        }
                        
                        stage('Build PC (Windows)') {
                            echo "Запуск экспорта Windows-проекта для теста..."
                            sh '''
                            if grep -q 'name="Windows Desktop"' export_presets.cfg 2>/dev/null; then
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
                        }

                        stage('Production Sign (Android)') {
                            echo "Переподписание боевым ключом (если он есть)..."
                            sh '''
                            if [ -f "build/alex_fight.apk" ]; then
                                if [ -f "release.keystore" ]; then
                                    zipalign -v -p 4 build/alex_fight.apk build/alex_fight-aligned.apk
                                    apksigner sign --ks release.keystore --ks-pass pass:YOUR_PASSWORD_HERE --out build/alex_fight-release.apk build/alex_fight-aligned.apk
                                    rm build/alex_fight.apk build/alex_fight-aligned.apk
                                else
                                    echo "Файл release.keystore не найден. Выполняем подпись с помощью debug.keystore..."
                                    if [ ! -f "debug.keystore" ]; then
                                        echo "Генерируем временный debug.keystore..."
                                        keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999
                                    fi
                                    zipalign -v -p 4 build/alex_fight.apk build/alex_fight-aligned.apk
                                    apksigner sign --ks debug.keystore --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android --out build/alex_fight-signed.apk build/alex_fight-aligned.apk
                                    rm build/alex_fight.apk build/alex_fight-aligned.apk
                                    mv build/alex_fight-signed.apk build/alex_fight.apk
                                fi
                            fi
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

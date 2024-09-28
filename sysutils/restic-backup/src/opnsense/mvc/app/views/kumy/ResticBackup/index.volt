<script type="text/javascript">
    /* eslint-env jquery */
    /* global mapDataToFormUI, saveFormToEndpoint, ajaxCall, stdDialogConfirm */

    $(function() {
        const body = $("body");

        function spinStart(selector) {
            $(selector).addClass("fa fa-spinner fa-pulse");
        }
        function spinStop(selector) {
            $(selector).removeClass("fa fa-spinner fa-pulse");
        }
        function pre(str) {
            return `<pre style="border: none">${str}</pre>`;
        }
        function displayMessage(message, type="info", duration=10000) {
            const r = (Math.random() + 1).toString(36).substring(7);
            $("#restic-notif-zone").append(`
                <div id="notif-${r}" class="alert alert-${type}" role="alert">
                    <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
                    ${message}
                </div>
            `);
            if (duration > 0) {
                setTimeout(function() {
                    $(`#notif-${r}`).remove();
                }, duration);
            }
        }

        // Promises generators
        function genMapDataToFormUIPromise(data_get_map, server_params, callback) {
            return new Promise((resolve, reject) => {
                mapDataToFormUI(data_get_map, server_params).done(function (data) {
                    console.log('data', data);
                    if (callback != null) {
                        callback(data);
                    }
                    if (Object.keys(data).length === 0) {
                        return reject(data);
                    }
                    resolve(data);
                });
            });
        }
        function genSaveFormPromise(url, form_id, callback_ok, disable_dialog, callback_fail) {
            return new Promise((resolve, reject) => {
                saveFormToEndpoint(url, form_id, function () {
                    if (callback_ok != null) {
                        callback_ok(data);
                    }
                    resolve(url);
                }, disable_dialog, function () {
                    if (callback_fail != null) {
                        callback_fail(data);
                    }
                    reject(url);
                });
            });
        }
        function genAjaxCallPromise(url, sendData={}, callback) {
            return new Promise((resolve) => {
                ajaxCall(url, sendData, callback);
                resolve(url);
            });
        }

        // Callbacks
        function GeneralSettingsCallback(data) {
            if (!('frm_GeneralSettings' in data))
                return;
            // $.each(data.frm_GeneralSettings.restic.UpdateCron, function(key, value) {
            $.each(data.frm_GeneralSettings["restic"]["UpdateCron"], function(key, value) {
                console.log('value', value);
                if (key && value.selected === 1) {
                    $("#tab_schedule")
                        .attr("href","/ui/cron/item/open/"+key)
                        .show();
                }
            });
        }

        // Load config
        Promise.all([
            genMapDataToFormUIPromise({'frm_GeneralSettings':"/api/resticbackup/GeneralSettings/get"}, null, callback=GeneralSettingsCallback),
            genMapDataToFormUIPromise({'frm_RepositoryLocalSettings':"/api/resticbackup/RepositoryLocalSettings/get"}),
            genMapDataToFormUIPromise({'frm_RepositoryMinioSettings':"/api/resticbackup/RepositoryMinioSettings/get"}),
        ]);

        // link save button to API set action
        $("#saveAct").on('click', function() {
            const settings_promises = [
                genSaveFormPromise("/api/resticbackup/GeneralSettings/set", 'frm_GeneralSettings'),
                genSaveFormPromise("/api/resticbackup/RepositoryLocalSettings/set", 'frm_RepositoryLocalSettings'),
                genSaveFormPromise("/api/resticbackup/RepositoryMinioSettings/set", 'frm_RepositoryMinioSettings'),
            ];
            const api_promises = [
                genAjaxCallPromise(url = "/api/resticbackup/service/reload"),
                genAjaxCallPromise(url = "/api/resticbackup/GeneralSettings/fetchCronIntegration"),
            ];

            spinStart('saveAct_progress');
            Promise.all(settings_promises)
                .then(() => {
                    return api_promises;
                })
                .then(api_promises => {
                    return Promise.all(api_promises);
                })
                .catch((err)=> console.log(err))
                .finally(function () {
                    spinStop('saveAct_progress');
                    setTimeout(function () {
                        window.location.reload();
                    }, 300);
                });
        });

        // Handle init buttons
        body.on('click', '.init-button', function() {
            const repository = $(this).data('repository');
            stdDialogConfirm(
                '{{ lang._('Confirm repository initialization') }}',
                '{{ lang._('Do you want to initialize the repository?') }}',
                '{{ lang._('Yes') }}',
                '{{ lang._('Cancel') }}',
                function () {
                    spinStart(`#init-${repository}_progress`);
                    ajaxCall(url="/api/resticbackup/service/init", sendData={repository: repository}, callback=function(data) {
                        displayMessage(pre(data['message'], data['status']));
                        spinStop(`#init-${repository}_progress`);
                    });
                },
                'danger'
            );
        })

        // Handle dry-run buttons
        body.on('click', '.dry-run-button', function() {
//             genSaveFormPromise("/api/resticbackup/RepositoryLocalSettings/set",'frm_RepositoryLocalSettings')
            const repository = $(this).data('repository');
            spinStart(`#dry-run-${repository}_progress`);
            ajaxCall(url="/api/resticbackup/service/dryrun", sendData={repository: repository}, callback=function(data) {
                displayMessage(pre(data['message']), data['status']);
                spinStop(`#dry-run-${repository}_progress`);
            });
        })

        // Handle backup buttons
        body.on('click', '.backup-button', function() {
            const repository = $(this).data('repository');
            spinStart(`#backup-${repository}_progress`);
            ajaxCall(url="/api/resticbackup/service/backup", sendData={repository: repository}, callback=function(data) {
                displayMessage(pre(data['message']), data['status']);
                spinStop(`#backup-${repository}_progress`);
            });
        })

        // Handle snapshots buttons
        body.on('click', '.snapshots-button', function() {
            const repository = $(this).data('repository');
            spinStart(`#snapshots-${repository}_progress`);
            ajaxCall(url="/api/resticbackup/service/snapshots", sendData={repository: repository}, callback=function(data) {
                displayMessage(pre(data['message']), data['status'], 0);
                spinStop(`#snapshots-${repository}_progress`);
            });
        })

        // Handle prune buttons
        body.on('click', '.prune-button', function() {
            // TODO
        })

    });
</script>

{%- macro create_repo_action_button(repository, button, text, class="btn-default") %}
    <button class="btn btn-{{ class }} {{ button }}-button" data-repository="{{ repository }}" type="button">
        <b>{{ text }}</b>
        <i id="{{ button }}-{{ repository }}_progress"></i>
    </button>
{%- endmacro %}
{%- macro create_action_button(button, text, class="btn-default") %}
    <button id="{{ button }}" class="btn btn-{{ class }}" type="button">
        <b>{{ text }}</b>
        <i id="{{ button }}_progress"></i>
    </button>
{%- endmacro %}
{%- macro add_repo_actions_buttons(lang, repository) %}
        <br>
        <div class="col-md-12">
            {{ create_repo_action_button(repository, "init", lang._('Initialize'), "danger") }}
            {{ create_repo_action_button(repository, "dry-run", lang._('Dry run'), "info") }}
            {{ create_repo_action_button(repository, "backup", lang._('Backup now'), "primary") }}
            {{ create_repo_action_button(repository, "snapshots", lang._('List snapshots'), "primary") }}
            {{ create_repo_action_button(repository, "prune", lang._('Prune'), "warning") }}
        </div>
        <br><br><br>
{%- endmacro %}

<div id="restic-notif-zone"></div>

<section class="page-content-main">

    <ul class="nav nav-tabs" data-tabs="tabs" id="maintabs">
        <li class="active"><a data-toggle="tab" href="#general" id="tab_general">{{ lang._('General') }}</a></li>
        <li><a href="#schedule" id="tab_schedule" style="display:none">{{ lang._('Update Schedule') }}</a></li>
        <li><a data-toggle="tab" href="#local" id="tab_local">Local</a></li>
        <!-- <li><a data-toggle="tab" href="#sftp" id="tab_sftp">SFTP</a></li> -->
        <!-- <li><a data-toggle="tab" href="#rest-server" id="tab_rest-server">REST Server</a></li> -->
        <!-- <li><a data-toggle="tab" href="#amazon-s3" id="tab_amazon-s3">Amazon S3</a></li> -->
        <li><a data-toggle="tab" href="#minio-server" id="tab_minio-server">Minio Server</a></li>
        <!-- <li><a data-toggle="tab" href="#s3-compatible" id="tab_s3-compatible">S3-compatible Storage</a></li> -->
        <!-- <li><a data-toggle="tab" href="#wasabi" id="tab_wasabi">Wasabi</a></li> -->
        <!-- <li><a data-toggle="tab" href="#alibaba-cloud" id="tab_alibaba-cloud">Alibaba Cloud</a></li> -->
        <!-- <li><a data-toggle="tab" href="#openstack-swift" id="tab_openstack-swift">OpenStack Swift</a></li> -->
        <!-- <li><a data-toggle="tab" href="#backblaze-b2" id="tab_backblaze-b2">Backblaze B2</a></li> -->
        <!-- <li><a data-toggle="tab" href="#microsoft-azure-blob-storage" id="tab_microsoft-azure-blob-storage">Microsoft Azure Blob Storage</a></li> -->
        <!-- <li><a data-toggle="tab" href="#google-cloud-storage" id="tab_google-cloud-storage">Google Cloud Storage</a></li> -->
        <!-- <li><a data-toggle="tab" href="#other-services-via-rclone" id="tab_other-services-via-rclone">Other Services via rclone</a></li> -->
    </ul>

    <div class="tab-content content-box">
        <div id="general"  class="tab-pane fade in active">
            {{ partial("layout_partials/base_form", ['fields': formGeneralSettings, 'id': 'frm_GeneralSettings']) }}
            <div class="alert alert-info" role="alert">
                Changing the password would require you to manually run <code>restic key passwd</code> command.
            </div>
            <div class="alert alert-warning" role="alert">
                Remembering your password is important! If you lose it, you won't be able to access data stored in the repository.
            </div>
        </div>
        <div id="schedule" class="tab-pane fade in"></div>
        <div id="local"  class="tab-pane fade in">
            {{ partial("layout_partials/base_form", ['fields': formRepositoryLocalSettings, 'id': 'frm_RepositoryLocalSettings']) }}
            {{ add_repo_actions_buttons(lang, "local") }}
        </div>
        <div id="sftp" class="tab-pane fade in"></div>
        <div id="rest-server" class="tab-pane fade in"></div>
        <div id="amazon-s3" class="tab-pane fade in"></div>
        <div id="minio-server" class="tab-pane fade in">
            {{ partial("layout_partials/base_form", ['fields': formRepositoryMinioSettings, 'id': 'frm_RepositoryMinioSettings']) }}
            {{ add_repo_actions_buttons(lang, "minio") }}
        </div>
        <div id="s3-compatible" class="tab-pane fade in"></div>
        <div id="wasabi" class="tab-pane fade in"></div>
        <div id="alibaba-cloud" class="tab-pane fade in"></div>
        <div id="openstack-swift" class="tab-pane fade in"></div>
        <div id="backblaze-b2" class="tab-pane fade in"></div>
        <div id="microsoft-azure-blob-storage" class="tab-pane fade in"></div>
        <div id="google-cloud-storage" class="tab-pane fade in"></div>
        <div id="other-services-via-rclone" class="tab-pane fade in"></div>
    </div>

    See <a href="https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html" target="_blank">restic documentation</a> for more details.
    <br/><br/>

    <div class="content-box">
        <div class="col-md-12">
            <br/>
            <button class="btn btn-primary" id="saveAct" type="button">
                <b>{{ lang._('Save') }}</b>
                <i id="saveAct_progress"></i>
            </button>
            {{ create_action_button("saveAct", lang._('Save'), "primary") }}
            <br/><br/>
        </div>
    </div>
</section>

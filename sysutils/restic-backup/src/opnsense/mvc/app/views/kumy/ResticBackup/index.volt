<script type="text/javascript">
    /* eslint-env jquery */
    /* global mapDataToFormUI, saveFormToEndpoint, ajaxCall, stdDialogConfirm, BootstrapDialog */

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
        function getRepository(selector) {
            const repository = $(selector).data('repository');
            const repositoryCamelCase = repository.charAt(0).toUpperCase() + repository.slice(1);
            return [repository, repositoryCamelCase];
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
            return new Promise((resolve, reject) => {
                ajaxCall(url, sendData, callback)
                    .done(() => {
                        resolve(url);
                    })
                    .fail(() => {
                        reject(url);
                    });
            });
        }

        // Callbacks
        function GeneralSettingsCallback(data) {
            if (!('frm_GeneralSettings' in data))
                return;
            $.each(data.frm_GeneralSettings["restic"]["UpdateCron"], function(key, value) {
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
            {% for repository in repositories %}
            {{ 'genMapDataToFormUIPromise({' ~ repository["form_id"] ~ ': "/api/resticbackup/' ~ repository["form_name"] ~ '/get" }),' }}
            {% endfor %}
        ]).then(() => {
            $('.selectpicker').selectpicker('refresh');
        })

        // link save button to API set action
        $("#save").on('click', function() {
            const settings_promises = [
                genSaveFormPromise("/api/resticbackup/GeneralSettings/set", 'frm_GeneralSettings'),
                genSaveFormPromise("/api/resticbackup/RepositoryLocalSettings/set", 'frm_RepositoryLocalSettings'),
                genSaveFormPromise("/api/resticbackup/RepositoryMinioSettings/set", 'frm_RepositoryMinioSettings'),
            ];
            const api_promises = [
                genAjaxCallPromise(url = "/api/resticbackup/service/reload"),
                genAjaxCallPromise(url = "/api/resticbackup/GeneralSettings/fetchCronIntegration"),
            ];

            spinStart('save_progress');
            Promise.all(settings_promises)
                .then(() => {
                    return api_promises;
                })
                .then(api_promises => {
                    return Promise.all(api_promises);
                })
                .then(() => {
                    setTimeout(function () {
                        // window.location.reload();
                        alert('reload');
                    }, 300);
                })
                .catch((err)=> console.error("Save form error:", err))
                .finally(() => {
                    spinStop('save_progress');
                });
        });


        function runRepositoryAction(repository, action, message_duration, resolve, reject) {
            ajaxCall(`/api/resticbackup/service/${action}`, sendData={repository: repository}, callback=function(data) {
                displayMessage(pre(data['message']), data['status'], message_duration);
            })
            .done(() => { resolve(); })
            .fail(() => { reject(); });
        }
        function runRepositoryActionInit(repository, action, message_duration, resolve, reject) {
            BootstrapDialog.confirm({
                title: '{{ lang._('Confirm repository initialization') }}',
                message: '{{ lang._('Do you want to initialize the repository?') }}',
                type: 'danger',
                btnCancelLabel: '{{ lang._('Cancel') }}',
                btnOKLabel: '{{ lang._('Yes') }}',
                btnOKClass: 'btn-danger',
                callback: function(result) {
                    if (result) {
                        runRepositoryAction(repository, action, message_duration, resolve, reject);
                    } else {
                        // Not using the stdDialogConfirm() helper due to miss of callback call on "cancel"
                        reject();
                    }
                }
            });
        }

        function bindRepositoryActionButton(action, callback, message_duration=10000) {
            body.on('click', `.${action}-button`, function() {
                const [repository, repositoryCamelCase] = getRepository(this);
                spinStart(`#${action}-${repository}_progress`);
                genSaveFormPromise(`/api/resticbackup/Repository${repositoryCamelCase}Settings/set`,`frm_Repository${repositoryCamelCase}Settings`)
                    .then(() => {
                        return Promise.all([genAjaxCallPromise(url = "/api/resticbackup/service/reload")]);
                    })
                    .then(() => {
                        return Promise.all([
                            new Promise((resolve, reject) => {
                                callback(repository, action, message_duration, resolve, reject);
                            })
                        ]);
                    })
                    .catch(() => {})
                    .finally(() => {
                        spinStop(`#${action}-${repository}_progress`);
                    });
            })
        }
        bindRepositoryActionButton("init", runRepositoryActionInit);
        bindRepositoryActionButton("dryrun", runRepositoryAction);
        bindRepositoryActionButton("backup", runRepositoryAction);
        bindRepositoryActionButton("snapshots", runRepositoryAction, 0);
        bindRepositoryActionButton("prune", runRepositoryAction);

    });
</script>

{%- macro create_repo_action_button(repository, action, text, class="btn-default") %}
    <button class="btn btn-{{ class }} {{ action }}-button" data-repository="{{ repository }}" type="button">
        <b>{{ text }}</b>
        <i id="{{ action }}-{{ repository }}_progress"></i>
    </button>
{%- endmacro %}
{%- macro create_action_button(action, text, class="btn-default") %}
    <button id="{{ action }}" class="btn btn-{{ class }}" type="button">
        <b>{{ text }}</b>
        <i id="{{ action }}_progress"></i>
    </button>
{%- endmacro %}
{%- macro add_repo_actions_buttons(lang, repository) %}
        <br>
        <div class="col-md-12">
            {{ create_repo_action_button(repository, "init", lang._('Initialize'), "danger") }}
            {{ create_repo_action_button(repository, "dryrun", lang._('Dry run'), "info") }}
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
        {% for repository in repositories %}
            <li><a data-toggle="tab" href="#{{ repository["name"] }}" id="tab_{{ repository["name"] }}">{{ repository["name_uc"] }}</a></li>
        {% endfor %}
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
        {% for repository in repositories %}
            <div id="{{ repository["name"] }}" class="tab-pane fade in">
                {{ partial("layout_partials/base_form", ['fields': repository["form_fields"], 'id': repository["form_id"]]) }}
                {{ add_repo_actions_buttons(lang, repository["name"]) }}
            </div>
        {% endfor %}
    </div>

    See <a href="https://restic.readthedocs.io/en/stable/030_preparing_a_new_repo.html" target="_blank">restic documentation</a> for more details.
    <br/><br/>

    <div class="content-box">
        <div class="col-md-12">
            <br/>
            {{ create_action_button("save", lang._('Save'), "primary") }}
            <br/><br/>
        </div>
    </div>
</section>

<?php

namespace kumy\ResticBackup\Api;

use OPNsense\Base\ApiMutableServiceControllerBase;
use OPNsense\Core\Backend;

class ServiceController extends ApiMutableServiceControllerBase
{
    protected static $internalServiceClass = '\kumy\ResticBackup\GeneralSettings';
    protected static $internalServiceTemplate = 'kumy/ResticBackup';
    protected static $internalServiceEnabled = 'enabled';
    protected static $internalServiceName = 'resticbackup';

    public function reloadAction()
    {
        $status = "failed";
        if ($this->request->isPost()) {
            $status = strtolower(trim((new Backend())->configdRun('template reload kumy/ResticBackup')));
        }
        return ["status" => $status];
    }

    public function initAction()
    {
        $status = "danger";
        $message = null;
        if ($this->request->isPost()) {
            $repository = $this->request->getPost('repository');
            $message = trim((new Backend())->configdRun(sprintf('restic init -r %s', $repository)));
            if (!str_contains($message, 'Fatal: ')) {
                $status = "success";
            };
        }
        return ['status' => $status, 'message' => $message];
    }

    public function dryrunAction()
    {
        $status = "danger";
        $message = null;
        if ($this->request->isPost()) {
            $repository = $this->request->getPost('repository');
            $message = trim((new Backend())->configdRun(sprintf('restic dry-run -r %s', $repository)));
            if (!str_contains($message, 'Fatal: ')) {
                $status = "success";
            };
        }
        return ['status' => $status, 'message' => $message];
    }

    public function backupAction()
    {
        $status = "danger";
        $message = null;
        if ($this->request->isPost()) {
            $repository = $this->request->getPost('repository');
            $message = trim((new Backend())->configdRun(sprintf('restic backup -r %s', $repository)));
            if (!str_contains($message, 'Fatal: ')) {
                $status = "success";
            };
        }
        return ['status' => $status, 'message' => $message];
    }

    public function snapshotsAction()
    {
        $status = "danger";
        $message = null;
        if ($this->request->isPost()) {
            $repository = $this->request->getPost('repository');
            $message = trim((new Backend())->configdRun(sprintf('restic snapshots -r %s', $repository)));
            if (!str_contains($message, 'Fatal: ')) {
                $status = "success";
            };
        }
        return ['status' => $status, 'message' => $message];
    }

    // public function testAction()
    // {
    //     if ($this->request->isPost()) {
    //         $bckresult = json_decode(trim((new Backend())->configdRun("helloworld test")), true);
    //         if ($bckresult !== null) {
    //             // only return valid json type responses
    //             return $bckresult;
    //         }
    //     }
    //     return ["message" => "unable to run config action"];
    // }

}
